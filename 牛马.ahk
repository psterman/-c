; ===================== msg =====================
#Requires AutoHotkey v2.0
A_MaxHotkeysPerInterval := 400
#Include modules\LocalPaths.ahk

NMER_StartupOnError(err, mode) {
    if (mode = "Return")
        return false
    line := 0
    try line := err.Line
    msg := "启动或运行出错：`n" . err.Message
    if (line)
        msg .= "`n`n" . err.File . " (行 " . line . ")"
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
    } catch {
    }
}

OnError(NMER_StartupOnError)
global NMER_TraceSession := FormatTime(A_Now, "yyyyMMdd-HHmmss") . "-" . A_TickCount
global pToken := Gdip_Startup()
if (!pToken) {
    MsgBox "GDI+ 启动失败，请检查 lib\ahk\Gdip_All.ahk"
}
NMER_Log("startup", "boot", "gdip=" . (pToken ? "ok" : "fail"))
try SurfaceManager_ObserveSystemBootstrap(Map("traceSession", NMER_TraceSession, "gdip", pToken ? 1 : 0))
; ScreenshotEditorPlugin #HotIf 可能在主脚本后部全局块执行前被求值，须尽早初始化
global ScreenshotColorPickerActive := false
; 托盘菜单可能在 Appearance / 悬浮模块全局块执行前被点击（TrayMenu_Init 很早），须尽早初始化
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
; TrayMenu_Init / UpdateTrayMenu 会立刻 GetText，须早于后部「多语言」全局块
global Language := "zh"
; ===================== 基础配置 =====================
#SingleInstance Force
SetTitleMatchMode(2)
SetControlDelay(-1)
SetKeyDelay(20, 20)
SetMouseDelay(10)
SendMode("Input")
DetectHiddenWindows(true)
; 设置坐标模式（用于拖动窗口等功能）
CoordMode("Mouse", "Screen")
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
; 托盘图标与 0x0404 自定义菜单：在 #Include lib\ahk\ImagePut.ahk 之后调用 TrayMenu_Init()（依赖 Gdip_All）

; ===================== 包含 SQLite 数据库类 =====================
; 包含 lib 文件夹中的 Class_SQLiteDB.ahk（AHK v2 版本）
#Include lib\ahk\Class_SQLiteDB.ahk
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

; ===================== 包含 OCR 模块 =====================
; 包含 lib 文件夹中的 OCR.ahk（用于识图取词功能）
#Include lib\ahk\OCR.ahk

; ===================== 包含 GDI+ 和 WinClip 库 =====================
; 包含 lib 文件夹中的 Gdip_All.ahk 和 WinClip.ahk（用于截图助手预览窗）
; 注意：WinClip.ahk 依赖于 WinClipAPI.ahk，需要先包含 WinClipAPI.ahk
#Include lib\ahk\Gdip_All.ahk
#Include lib\ahk\WinClipAPI.ahk
#Include lib\ahk\WinClip.ahk

; ===================== 包含 ImagePut 库 =====================
; 包含 lib 文件夹中的 ImagePut.ahk（用于简化图片处理，提高性能和功能）
#Include lib\ahk\ImagePut.ahk

#Include modules\TrayMenuManager.ahk
TrayMenu_Init()

; ===================== 定义主脚本目录（供模块使用）=====================
global MainScriptDir := A_ScriptDir

; SearchCenterCore 须在剪贴板库 Init 之后再拉起（见文末 InitClipboardFTS5DB 之后）

; ===================== WM_ACTIVATE 链（须在任意 OnMessage(0x0006) 模块之前）=====================
#Include modules\WMActivateChain.ahk

; ===================== 包含新的剪贴板管理器模块 =====================
#Include modules\ClipboardFTS5.ahk
#Include modules\SpeechSAPI.ahk
#Include modules\ClipboardHistoryPanel.ahk
#Include modules\ClipboardPanelCore.ahk
#Include modules\ShellIconCache.ahk
#Include modules\FileClassifier.ahk

; CLI 启动逻辑须在 NiumaTtyd 之前，以便 ttyd 解析各引擎可执行文件（与搜索中心同源）
#Include modules\VoiceInputCliEffects.ahk
; ttyd 本机终端（Niuma Chat CLI）：须在 FloatingToolbar 之前包含，供 Web 消息与定时器引用
#Include modules\NiumaTtyd.ahk
#Include modules\NiumaOllama.ahk
#Include modules\CloudPlayer.ahk
; Hermes / LLM 探测须在 FloatingToolbar 之前加载，供 NiumaChat 一键连接读 .env
#Include modules\LlmApiPing.ahk
#Include modules\UserStudio.ahk

; ===================== 包含悬浮工具栏模块 =====================
global CommandPaletteUseWebView := true
#Include modules\HoleWhisperStt.ahk
#Include modules\WailsWhisperVoice.ahk
#Include modules\WailsNativeInput.ahk
#Include modules\GlobalDragHoleOverlay.ahk
#Include modules\NativeDropCursorSync.ahk
#Include modules\FloatingToolbar.ahk
#Include modules\FloatingToolbarWailsHost.ahk
#Include modules\FloatingToolbarRouter.ahk
#Include modules\NmerWailsBridge.ahk
#Include modules\SurfaceRuntimeManager.ahk
#Include modules\SurfaceTransaction.ahk
#Include modules\SurfaceIntentRouter.ahk
#Include modules\SurfaceDisposeProbe.ahk
try SurfaceManager_ObserveSystemBootstrap(Map(
    "traceSession", NMER_TraceSession,
    "gdip", pToken ? 1 : 0,
    "phase", "includes_ready",
    "managerEnabled", FuncExists("Nmer_SurfaceManagerEnabled") ? (Nmer_SurfaceManagerEnabled() ? 1 : 0) : -1,
    "shadowMode", FuncExists("Nmer_SurfaceManagerShadowMode") ? (Nmer_SurfaceManagerShadowMode() ? 1 : 0) : -1,
    "routeIntents", FuncExists("Nmer_SurfaceManagerRouteIntents") ? (Nmer_SurfaceManagerRouteIntents() ? 1 : 0) : -1,
    "useTransactions", FuncExists("Nmer_SurfaceManagerUseTransactions") ? (Nmer_SurfaceManagerUseTransactions() ? 1 : 0) : -1,
    "interceptOpenClose", FuncExists("Nmer_SurfaceManagerInterceptOpenClose") ? (Nmer_SurfaceManagerInterceptOpenClose() ? 1 : 0) : -1,
    "interceptWarmup", FuncExists("Nmer_SurfaceManagerInterceptWarmup") ? (Nmer_SurfaceManagerInterceptWarmup() ? 1 : 0) : -1,
    "enforceBudget", FuncExists("Nmer_SurfaceManagerEnforceBudget") ? (Nmer_SurfaceManagerEnforceBudget() ? 1 : 0) : -1,
    "enforceSlots", FuncExists("Nmer_SurfaceManagerEnforceSlots") ? (Nmer_SurfaceManagerEnforceSlots() ? 1 : 0) : -1
))
#Include modules\CommandPaletteCore.ahk
#Include modules\CommandPaletteWailsHost.ahk
#Include modules\CommandPaletteRouter.ahk
#Include modules\CommandPaletteAgentOrchestrator.ahk
#Include modules\CommandPaletteSearchDebug.ahk
#Include modules\MultiCardMemoryProbe.ahk
global g_CmdPal_AgentSubmitDispatch := CommandPalette_HandleAgentSubmit
global g_CmdPal_AgentDebugTraceDispatch := CommandPalette_AgentDebugTrace
global g_CmdPal_AgentWireLogDispatch := CommandPalette_AgentWireLog
global g_CmdPal_AgentPullDebugDispatch := CommandPaletteSearchDebug_PullAgentDebugJson
#Include modules\FloatingBubble.ahk
#Include modules\GravityPump.ahk
#Include modules\AIListPanel.ahk
#Include modules\PromptQuickPadCore.ahk
#Include modules\SearchCenterWebViewCore.ahk
#Include modules\DomainCSurfaceRouter.ahk
#Include modules\DomainCWailsHost.ahk
#Include modules\SelectionSenseCore.ahk
#Include modules\HoleActivationRouter.ahk
#Include modules\HoleActivationTriggers.ahk
#Include modules\PromptSyncService.ahk
#Include modules\PromptQuickPadCapsLockB.ahk

#Include modules\EverythingClient.ahk

; 洞与工具栏同时启用：默认使用本地静态页，避免 dev server/端口探测阻塞导致启动假死
if (EnableHoleOverlay || EnableHoleOverlayOnNativeDrop) {
    holeFallbackUrl := GDHO_BuildFileUrl(HtmlPanelPath("hole_starry.html"))
    try GDHO_SetFallbackUrl(holeFallbackUrl)
    if (IsSet(GDHO_DECOUPLED_TOPOLOGY) && GDHO_DECOUPLED_TOPOLOGY) {
        panelFallbackUrl := GDHO_BuildFileUrl(HtmlPanelPath("hole_panel.html"))
        try GDHO_SetPanelFallbackUrl(panelFallbackUrl)
        try GDHO_SetPanelPageUrl(panelFallbackUrl)
    }
}
if (EnableHoleOverlayOnNativeDrop) {
    holeFallbackUrl := GDHO_BuildFileUrl(HtmlPanelPath("hole_starry.html"))
    try GDHO_SetFallbackUrl(holeFallbackUrl)
}

OnExit((*) => (NativeDropBridge_Stop(), Nmer_StopWailsBridge()))
NativeDropBridge_InitCopyDataReceiver()

; 已移除强制管理员自提权，避免与 Everything 产生权限不一致导致 IPC 失败。

; 全局变量（v2用Class/全局变量管理）
global CapsLockDownTime := 0
global IsCommandMode := false
global PanelVisible := false
global GuiID_CursorPanel := 0
global CursorPanelDescText := 0  ; 快捷操作面板说明文字控件
global CursorPanelAlwaysOnTop := false  ; 面板是否置顶（默认不置顶）
global CursorPanelAutoHide := false  ; 面板是否启用靠边自动隐藏
global CursorPanelHidden := false  ; 面板是否已隐藏（靠边时）
global CursorPanelWidth := 680  ; 面板宽度（参考 Raycast 和 uTools 的默认宽度）
global CursorPanelHeight := 0  ; 面板高度（动态计算）
global CursorPanelSearchEdit := 0  ; 快捷操作面板搜索输入框
global CursorPanelResultLV := 0  ; 快捷操作面板搜索结果ListView
global CursorPanelSearchResults := []  ; 快捷操作面板搜索结果数组
global CursorPanelShowMoreBtn := 0  ; 快捷操作面板"更多"按钮
global CursorPanelSearchDebounceTimer := 0  ; 快捷操作面板搜索防抖定时器
Nmer_MigrateLocalData()
Nmer_MigrateToolsBinaries()
Nmer_EnsureSqliteDbIni()
global ConfigFile := Nmer_MainConfigFile()
global TrayIconPath := A_ScriptDir "\cursor_helper.ico"
; CustomIconPath 由 modules\TrayMenuManager.ahk 初始化
; CapsLock+ 方案的核心变量
global CapsLock := false
global GuiID_ConfigGUI := 0  ; 配置面板单例
global UseWebViewSettings := true  ; 恢复 WebView 设置页
global g_ConfigOpenInFlight := false
global g_ConfigOpenInFlightSince := 0
global g_ConfigPreferWebViewOnly := true
global g_ConfigOpenEntryMode := ""
global ConfigWebViewMode := false
global ConfigWV2Ctrl := 0
global ConfigWV2 := 0
global ConfigWV2Ready := false
global ConfigWebViewPreloaded := false
global g_ConfigWebView_LastShown := 0  ; ShowConfigWebViewGUI 后时间戳，WM_ACTIVATE 宽限期避免刚显示即被关
global g_ConfigWebViewOpenStartTick := 0
global g_ConfigUserClosedTick := 0
global UnifiedAssetsHost := "app.local"
global UnifiedAssetsRoot := A_ScriptDir
global UnifiedAssetsAccessKind := 0  ; COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_ALLOW
; Allow WebView2 to open ws:// from https://app.local (OpenClaw Gateway is local ws).
global WebView2DefaultOptions := { AdditionalBrowserArguments: "--allow-running-insecure-content --renderer-process-limit=3 --disable-features=CalculateNativeWinOcclusion" }
global WebViewMsgQueue := []
global WebViewMsgQueueActive := false
global WebViewWarmupQueue := []
global WebViewWarmupIndex := 0
global WebViewWarmupStarted := false
global DefaultStartTabDDL_Hwnd := 0  ; 默认启动页面下拉框句柄
global DefaultStartTabDDL_Hwnd_ForTimer := 0  ; 默认启动页面下拉框句柄（用于定时器）
global DDLBrush := 0  ; 下拉列表背景画刷
global MoveGUIListBoxHwnd := 0  ; 移动分类弹窗ListBox句柄
global MoveGUIListBoxBrush := 0  ; 移动分类弹窗ListBox画刷
global MoveFromTemplateListBoxHwnd := 0  ; 从模板移动弹窗ListBox句柄
global MoveFromTemplateListBoxBrush := 0  ; 从模板移动弹窗ListBox画刷
global CapsLock2 := false  ; 是否使用过 CapsLock+ 功能标记，使用过会清除这个变量
global CapsLockInitialStateForChord := false  ; 记录按下 CapsLock 前状态，供组合键快速恢复
global LastCapsLockTapTick := 0  ; CapsLock 双击判定（CursorPanelController CapsLock:: 松手逻辑）
global CapsLockPressTime := 0
global VKHoldVisible := false  ; 是否由长按 CapsLock 暂时显示 VK
; 动态快捷键映射（默认值）
global SplitHotkey := "s"
global BatchHotkey := "b"
global HotkeyESC := "Esc"  ; 关闭面板
global HotkeyC := "c"  ; 连续复制
global HotkeyV := "v"  ; 合并粘贴
global HotkeyX := "x"  ; 打开剪贴板管理面板
global HotkeyE := "e"  ; 执行解释
global HotkeyR := "r"  ; 执行重构
global HotkeyO := "o"  ; 执行优化
global HotkeyQ := "q"  ; 打开配置面板
global HotkeyZ := "z"  ; 语音输入
global HotkeyF := "f"  ; 语音搜索
global HotkeyT := "t"  ; 区域截图
global HotkeyP := "p"  ; 截图粘贴
global PromptQuickCaptureHotkey := ""  ; Prompt Quick-Pad 选区采集，留空不注册；可在 CursorShortcut.ini [Settings] PromptQuickCaptureHotkey 配置
global CursorShortcut_CommandPalette := "^+p"
global CursorShortcut_Terminal := "^+``"
global CursorShortcut_GlobalSearch := "^+f"
global CursorShortcut_Explorer := "^+e"
global CursorShortcut_SourceControl := "^+g"
global CursorShortcut_Extensions := "^+x"
global CursorShortcut_Browser := "^+b"
global CursorShortcut_Settings := "^+j"
global CursorShortcut_CursorSettings := "^,"
global PromptQuickPad_CapsLockBSilent := false  ; CapsLock+B 静默入库（ini [PromptQuickPad] CapsLockBSilent=1）
global PromptQuickPad_CapsLockBSilentToTemplate := false  ; 静默时写入模板库 PromptTemplates.ini（否则 prompts.json）
global PromptQuickPad_CapsLockBDefaultTitle := "摘录"
global PromptQuickPad_CapsLockBDefaultCategory := ""
global PromptQuickPad_CapsLockBDefaultTags := ""
; 截图等待粘贴相关变量
global ScreenshotWaiting := false  ; 是否正在等待粘贴截图
global ScreenshotImageDetected := false  ; OnClipboardChange 检测到截图图片
global ScreenshotClipboard := ""  ; 保存的截图剪贴板内容
global ScreenshotLastFilePath := ""  ; 当系统截图未写入位图剪贴板时，回退使用最新保存图片路径
global ScreenshotOldClipboard := ""  ; 截图流程保存的剪贴板快照
global ScreenshotCheckTimer := 0  ; 截图检测定时器
global g_ExecuteScreenshotWithMenuBusy := false  ; 防重复进入截图流程（避免双重助手/工具栏）
global FloatingToolbar_ScheduleRestoreAfterScreenshot := false  ; 从悬浮条发起截图时，在助手显示前恢复工具栏
global GuiID_ScreenshotButton := 0  ; 截图悬浮按钮 GUI ID
global ScreenshotButtonVisible := false  ; 截图按钮是否可见
global ScreenshotPanelX := -1  ; 截图面板 X 坐标（-1 表示使用默认居中位置）
global ScreenshotPanelY := -1  ; 截图面板 Y 坐标（-1 表示使用默认居中位置）
; 剪贴板智能菜单相关变量
global GuiID_ClipboardSmartMenu := 0  ; 剪贴板智能菜单 GUI ID
; 以下由 modules\ScreenshotEditorPlugin 在 Show/Close 时 _SyncHub() 写回，供 LegacyConfigGui / #HotIf 等使用
global GuiID_ScreenshotEditor := 0  ; 截图助手主窗口
global GuiID_ScreenshotToolbar := 0  ; 截图工具栏窗口
global ScreenshotEditorPreviewPic := 0  ; 预览区 Picture（LegacyConfigGui 右键上下文）
global ScreenshotColorPickerActive := false  ; 取色器开启时 #HotIf（与插件内 static 同步）
global ClipboardMenuButtons := []  ; 按钮数组
global ClipboardMenuSelectedIndex := 0  ; 当前选中的按钮索引
global ClipboardMenuOptions := []  ; 选项数组
global ClipboardMenuHotkeysRegistered := false  ; 热键是否已注册
; 配置变量
global CursorPath := ""
global AISleepTime := 15000
global CapsLockHoldTimeSeconds := 0.5  ; 长按达到该秒数后显示 VK KeyBinder，松手隐藏（若本窗口原已打开则松手不隐藏）
global CapsLockHoldVkEnabled := true  ; 是否启用长按 CapsLock 弹出 VK KeyBinder（设置中心 / ini：CapsLockHoldVkEnabled）
global Prompt_Explain := ""
global Prompt_Refactor := ""
global Prompt_Optimize := ""
; 提示词模板系统
global PromptTemplates := []  ; 模板数组 [{ID, Title, Content, Icon, FunctionCategory, Series, Category(兼容旧版本)}]
global DefaultTemplateIDs := Map()  ; 默认模板映射 {"Explain" => TemplateID, "Refactor" => TemplateID, "Optimize" => TemplateID}
global PromptTemplatesFile := Nmer_PromptTemplatesFile()  ; 模板配置文件
global ExpandedTemplateKey := ""  ; 当前展开的模板键（格式：FunctionCategory_Series_Index）
global CategoryMap := Map()  ; 双层分类索引 CategoryMap[功能分类ID][模板系列ID] = 模板数组
; 性能优化索引（O(1)查找）
global TemplateIndexByID := Map()  ; ID -> Template 对象，用于快速查找
global TemplateIndexByTitle := Map()  ; "Category|Title" -> Template 对象，用于快速查找
global TemplateIndexByArrayIndex := Map()  ; ArrayIndex -> Template 对象，用于获取数组索引
global CategoryMapDirty := true  ; 标记分类映射是否需要重建（缓存机制）
global FunctionCategories := Map()  ; 功能分类定义 {ID: {Name, SortWeight}}
global SeriesCategories := Map()  ; 模板系列定义 {ID: {Name, SortWeight}}
global ExpandedState := Map()  ; 展开状态管理 {功能分类ID: {模板系列ID: 展开的模板ID}}
global CategoryExpandedState := Map()  ; 每个分类的展开状态 {CategoryName: TemplateKey}
global CurrentFunctionCategory := "Explain"  ; 当前选中的功能分类
global CurrentPromptFolder := ""  ; 当前查看的prompt文件夹（为空表示显示主文件夹列表）
global PromptManagerListView := 0  ; 模板管理器ListView控件
; 面板位置和屏幕配置
global PanelScreenIndex := 1  ; 屏幕索引（1为主屏幕）
global PanelPosition := "center"  ; 位置：center, top-left, top-right, bottom-left, bottom-right, custom
global FunctionPanelPos := "center"
global ConfigPanelPos := "center"
global ClipboardPanelPos := "center"
; 各面板的屏幕索引
global ConfigPanelScreenIndex := 1  ; 配置面板屏幕索引
global MsgBoxScreenIndex := 1  ; 弹窗屏幕索引
global VoiceInputScreenIndex := 1  ; 语音输入法提示屏幕索引
global CursorPanelScreenIndex := 1  ; cursor快捷弹出面板屏幕索引
global ClipboardPanelScreenIndex := 1  ; 剪贴板管理面板屏幕索引
global PanelX := -1  ; 自定义 X 坐标（-1 表示使用默认位置）
global PanelY := -1  ; 自定义 Y 坐标（-1 表示使用默认位置）
; 连续复制功能
global ClipboardHistory := []  ; 存储所有复制的内容（兼容旧版本，保留）
global ClipboardHistory_CtrlC := []  ; 存储 Ctrl+C 复制的内容
global ClipboardHistory_CapsLockC := []  ; 存储 CapsLock+C 复制的内容
global GuiID_ClipboardManager := 0  ; 剪贴板管理面板 GUI ID
global ClipboardManagementResultLimitDropdown := 0  ; 剪贴板管理结果数量限制下拉菜单
global ClipboardManagementEverythingLimit := 50  ; 剪贴板管理 Everything 搜索限制值
; CapsLock+C 叠加复制计数和存储
global CapsLockCCount := 0  ; 当前阶段的复制计数
global CapsLockCCountTooltip := 0  ; 计数提示 Tooltip 句柄
global CapsLockCItems := []  ; 存储当前阶段 CapsLock+C 复制的所有内容
; SQLite 数据库
global ClipboardDB := 0  ; SQLite 数据库对象
global ClipboardDBPath := Nmer_CursorDataDbPath()  ; 数据库文件路径（Data/CursorData.db）
global ClipboardCurrentTab := "CtrlC"  ; 当前显示的版块："CtrlC" 或 "CapsLockC"
global ClipboardCapsLockCTab := 0  ; CapsLock+C Tab 控件引用
global LastSelectedIndex := 0  ; 最后选中的ListBox项索引，用于刷新后恢复
global ClipboardListViewHighlightedRow := 0  ; ListView 高亮的单元格行索引（从1开始，0表示无高亮）
global ClipboardListViewHighlightedCol := 0  ; ListView 高亮的单元格列索引（从1开始，0表示无高亮）
global ClipboardListViewHwnd := 0  ; ListView 控件句柄，用于 WM_NOTIFY 消息识别
global ClipboardManagerHwnd := 0  ; 剪贴板管理窗口句柄，用于 WM_NOTIFY 消息识别
global ClipboardCurrentCategory := ""  ; 当前选中的分类（空字符串表示全部，不添加过滤条件；其他值：Text, Code, Link, Image等）
global ClipboardCategoryButtons := []  ; 分类标签按钮数组
global ClipboardHighlightOverlay := 0  ; 单元格高亮覆盖层GUI对象
global ClipboardHighlightOverlayBrush := 0  ; 覆盖层画刷句柄（用于清理资源）
; 搜索功能相关变量
global ClipboardSearchMatches := []  ; 搜索匹配项列表 [{RowIndex, ColIndex, ID}]
global ClipboardSearchCurrentIndex := 0  ; 当前匹配项索引（从0开始）
global ClipboardSearchKeyword := ""  ; 当前搜索关键词
global ClipboardSearchTimer := 0  ; 搜索防抖定时器（参考 SearchCenter 的实现）
; 语音输入功能
global VoiceInputActive := false  ; 语音输入是否激活
global GuiID_VoiceInput := 0  ; 语音输入动画GUI ID
global GuiID_VoiceInputPanel := 0  ; 语音输入面板GUI ID
global GuiID_SearchCenter := 0  ; 搜索中心窗口GUI ID
; 搜索中心相关变量
global SearchCenterActiveArea := "input"  ; 当前激活区域："category"、"input" 或 "listview"
global SearchCenterCurrentCategory := 0  ; 当前选中的分类索引（0-based）
global SearchCenterCurrentGroup := 0  ; 当前选中的搜索组索引（0-based）
global SearchCenterSearchEdit := 0  ; 搜索输入框控件
global SearchCenterResultLV := 0  ; 搜索结果 ListView 控件
global SearchCenterCategoryButtons := []  ; 分类标签按钮数组
global SearchCenterSearchResults := []  ; 当前搜索结果数据
global SearchCenterVisibleResults := []  ; 当前结果列表中实际可见的数据
global SearchCenterEngineIcons := []  ; 搜索引擎图标控件数组
global SearchCenterCLIOutputEdit := 0
global SearchCenterCLIRunButton := 0
global SearchCenterCLIClearButton := 0
global SearchCenterCLIOpenButton := 0
global CLIAgentPendingPrompts := Map()
global CLIAgentPromptMonitorRunning := false
; Gemini 就绪：由「非登录态 + 窗口文本连续稳定」判定，非固定秒数；可按机器/习惯改下列参数（Monitor 轮询 500ms）
global CLIGeminiReadyMinMs := 2500
global CLIGeminiStablePollsRequired := 4
global CLIGeminiForceSendAfterMs := 55000
; Windows Terminal 等宿主下 WinGetText 常为空，需「无文本」回退；此前达到该时长后才开始计 EmptyPolls
global CLIGeminiNoTextMinMs := 8000
global SearchCenterResultLimitDropdown := 0  ; 结果数量限制下拉菜单
global SearchCenterResultLimitDDL_Hwnd := 0  ; 搜索中心结果过滤下拉框句柄
global SearchCenterResultLimitDDL_ListHwnd := 0  ; 搜索中心结果过滤下拉列表句柄
global SearchCenterResultLimitDDLBrush := 0  ; 搜索中心结果过滤下拉框画刷
global SearchCenterEverythingLimit := 30  ; Everything 搜索的结果数量限制（默认30）
global FileClassifierUserTrustRoots := []  ; 用户自定义高信任路径前缀（可选，供 FileClassifier.GetPathTrustMultiplier 使用）
global SearchCenterCurrentLimit := 30  ; 当前加载的数据量限制
global SearchCenterHasMoreData := false  ; 是否还有更多数据
global SearchCenterSelectedEngines := []  ; 搜索中心选中的搜索引擎（支持多选）
global SearchCenterSelectedEnginesByCategory := Map()  ; 每个分类的搜索引擎选择状态（分类Key -> 引擎数组）
global SearchCenterHintText := 0  ; 搜索中心操作提示文本控件
global SearchCenterAreaIndicator := 0  ; 搜索中心区域指示器控件（动效）
global SearchCenterInputContainer := 0  ; 搜索中心输入框边框容器控件（Material Design风格）
global SearchCenterFilterType := ""  ; 搜索中心当前过滤类型（空字符串表示全部）
global SearchCenterFilterButtons := []  ; 搜索中心过滤标签按钮数组
global SearchCenterFilterButtonMap := Map()  ; 搜索中心过滤标签按钮映射（FilterType -> 控件）
global GlobalSearchStatement := 0  ; 全局搜索 Statement 对象（用于熔断机制）
global global_ST := 0  ; 全局 Statement 句柄（终极闭环管理）
global SearchDebounceTimer := 0  ; 配置面板/快捷面板搜索防抖（与搜索中心分离，避免互相覆盖）
global SearchCenterDebounceTimer := 0  ; 搜索中心 CapsLock+F 专用防抖
global SearchCenterCapsChord_Debug := false  ; 设为 true 时 OutputDebug 搜索中心 CapsLock+和弦（ISA/GCLS/cmdId/SCWV_Ready）
; 圆环倒计时模块
global LaunchDelaySeconds := 3.0  ; 倒计时时长（秒）
global IsCountdownActive := false  ; 倒计时是否激活
global CountdownGui := 0  ; 倒计时 GUI 对象
global CountdownTimer := 0  ; 倒计时定时器
global CountdownStartTime := 0  ; 倒计时开始时间
global CountdownGraphics := 0  ; GDI+ Graphics 对象
global CountdownBitmap := 0  ; GDI+ Bitmap 对象
global CountdownContent := ""  ; 待粘贴的内容
global VoiceInputContent := ""  ; 存储语音输入的内容
global VoiceInputMethod := ""  ; 当前使用的输入法类型：baidu, xunfei, auto
global VoiceInputPaused := false  ; 语音输入是否被暂停（按住CapsLock时）
global VoiceTitleText := 0  ; 语音输入动画标题文本控件
global VoiceHintText := 0  ; 语音输入动画提示文本控件
global VoiceAnimationText := 0  ; 语音输入/搜索动画文本控件
global VoiceInputStatusText := 0  ; 语音输入状态文本控件
global VoiceInputSendBtn := 0  ; 语音输入发送按钮
global VoiceInputPauseBtn := 0  ; 语音输入暂停/继续按钮
global VoiceSearchInputEdit := 0  ; 语音搜索输入框控件
global VoiceSearchEngineButtons := []  ; 搜索引擎按钮数组
global VoiceSearchInputLastEditTime := 0  ; 输入框最后编辑时间（用于检测用户是否正在输入）
; 语音搜索功能
global VoiceSearchActive := false  ; 语音搜索是否激活
global VoiceSearchContent := ""  ; 存储语音搜索的内容
global SearchEngine := "deepseek"  ; 默认搜索引擎：deepseek, yuanbao, doubao, zhipu, mita, wenxin, qianwen, kimi
global VoiceSearchSelecting := false  ; 是否正在选择搜索引擎
global VoiceSearchPanelVisible := false  ; 语音搜索面板是否显示
global VoiceSearchSelectedEngines := ["deepseek"]  ; 当前在语音搜索界面中选择的搜索引擎（支持多选）
global VoiceSearchCurrentCategory := "ai"  ; 当前选中的搜索引擎分类标签
global VoiceSearchCategoryTabs := []  ; 分类标签按钮数组
global VoiceSearchSelectedEnginesByCategory := Map()  ; 每个分类的搜索引擎选择状态（分类Key -> 引擎数组）
global AutoLoadSelectedText := false  ; 是否自动加载选中文本到输入框
global VoiceSearchAutoLoadSwitch := 0  ; 自动加载开关控件（语音搜索）
global VoiceInputAutoLoadSwitch := 0  ; 自动加载开关控件（语音输入）
global AutoUpdateVoiceInput := true  ; 是否自动更新语音输入内容到输入框
global AutoStart := false  ; 是否开启自启动
global VoiceSearchEnabledCategories := []  ; 启用的搜索标签列表
global VoiceSearchAutoUpdateSwitch := 0  ; 自动更新开关控件（语音搜索）
global VoiceInputActionSelectionVisible := false  ; 语音输入操作选择界面是否显示
; 配置面板搜索功能相关变量
global SearchTabControls := []  ; 搜索标签页控件数组
global SearchHistoryEdit := 0  ; 搜索输入框控件
global SearchResultsListView := 0  ; 搜索结果ListView控件
global SearchResultsData := Map()  ; 搜索结果数据映射（行索引 -> 结果项）
global SearchResultsCache := Map()  ; 搜索结果缓存
global SearchLastKeyword := ""  ; 上次搜索关键词
global SearchCurrentFilterType := ""  ; 当前过滤类型（空字符串表示全部）
global SearchTypeFilterButtons := []  ; 类型过滤按钮数组
; 窗口拖动状态跟踪（用于防止拖动时组件闪烁）
global WindowDragging := false  ; 是否正在拖动窗口
global DraggingTimers := Map()  ; 存储拖动时需要暂停的定时器 {TimerName: TimerID}
; 多语言支持
global Language := "zh"  ; 语言设置：zh=中文, en=英文
global DefaultStartTab := "general"  ; 默认启动页面：general=通用, appearance=外观, prompts=提示词, hotkeys=快捷键, advanced=高级
; 快捷操作按钮（历史产物，已移除 QuickActions 面板与槽位配置；保留空数组供旧版 GUI 残留引用）
global QuickActionButtons := []
global FloatingToolbarButtonItems := ["Search", "Record", "Prompt", "NewPrompt", "Screenshot", "Settings", "VirtualKeyboard"]
global FloatingToolbarMenuItems := ["ToggleToolbar", "MinimizeToEdge", "ResetScale", "SearchCenter", "Clipboard", "OpenConfig", "HideToolbar", "ReloadScript", "ExitApp"]
global FloatingToolbarButtonOptions := [
    Map("id", "Search", "name", "搜索"),
    Map("id", "Record", "name", "记录"),
    Map("id", "Prompt", "name", "提示词"),
    Map("id", "NewPrompt", "name", "草稿本"),
    Map("id", "Screenshot", "name", "截图"),
    Map("id", "Settings", "name", "设置"),
    Map("id", "VirtualKeyboard", "name", "虚拟键盘")
]
global FloatingToolbarMenuOptions := [
    Map("id", "ToggleToolbar", "name", "显示/隐藏工具栏"),
    Map("id", "MinimizeToEdge", "name", "最小化到边缘"),
    Map("id", "ResetScale", "name", "重置大小"),
    Map("id", "SearchCenter", "name", "搜索中心"),
    Map("id", "Clipboard", "name", "剪贴板"),
    Map("id", "OpenConfig", "name", "打开设置"),
    Map("id", "HideToolbar", "name", "关闭工具栏"),
    Map("id", "ReloadScript", "name", "重启脚本"),
    Map("id", "ExitApp", "name", "退出程序")
]

; 激活方式：toolbar=悬浮栏 bubble=悬浮球(滚轮缩小) hole=黑洞模式 tray=后台（仅托盘，无悬浮 UI）
global AppearanceActivationMode := "toolbar"

; ===================== UI 颜色初始化（必须在脚本早期初始化）=====================
; 主题模式：dark（暗色，默认）或 light（亮色）
global ThemeMode := "dark"
global g_ThemeApplyInFlight := false
global g_ThemeApplyToken := 0

; 暗色主题颜色
UI_Colors_Dark := {
    Background: "0a0a0a",      ; html.to.design 风格：深黑色背景
    Sidebar: "1a1a1a",         ; html.to.design 风格：侧边栏深灰色
    Border: "333333",          ; html.to.design 风格：边框深灰色
    Text: "f5f5f5",            ; html.to.design 风格：主文本浅灰色
    TextDim: "888888",         ; html.to.design 风格：次要文本中灰色
    InputBg: "1a1a1a",         ; html.to.design 风格：输入框背景
    DDLBg: "1a1a1a",           ; html.to.design 风格：下拉框背景
    DDLBorder: "333333",       ; html.to.design 风格：下拉框边框
    DDLText: "f5f5f5",         ; html.to.design 风格：下拉框文本
    DDLHover: "2a2a2a",        ; html.to.design 风格：下拉框悬停
    BtnBg: "1a1a1a",           ; html.to.design 风格：按钮背景
    BtnHover: "2a2a2a",        ; html.to.design 风格：按钮悬停
    BtnPrimary: "e67e22",      ; html.to.design 风格：主按钮橙色
    BtnPrimaryHover: "d35400", ; html.to.design 风格：主按钮悬停深橙色
    BtnDanger: "e81123",       ; 保持红色危险按钮
    BtnDangerHover: "c50e1f",  ; 保持红色危险按钮悬停
    TabActive: "2a2a2a",       ; html.to.design 风格：激活标签
    TitleBar: "1a1a1a"         ; html.to.design 风格：标题栏
}

; 亮色主题颜色
UI_Colors_Light := {
    Background: "ffffff",
    Sidebar: "f3f3f3",
    Border: "d0d0d0", 
    Text: "333333",
    TextDim: "666666",
    InputBg: "ffffff",
    DDLBg: "ffffff",
    DDLBorder: "d0d0d0",
    DDLText: "333333",
    DDLHover: "e8e8e8",
    BtnBg: "e8e8e8",
    BtnHover: "d0d0d0",
    BtnPrimary: "0078D4",
    BtnPrimaryHover: "1177bb",
    BtnDanger: "e81123",
    BtnDangerHover: "c50e1f",
    TabActive: "e8e8e8",
    TitleBar: "f3f3f3"
}

; 初始化UI颜色（默认暗色）
global UI_Colors := UI_Colors_Dark

; 应用主题
ApplyTheme(Mode) {
    global UI_Colors, ThemeMode, UI_Colors_Dark, UI_Colors_Light
    global g_ThemeApplyInFlight, g_ThemeApplyToken
    g_ThemeApplyInFlight := true
    g_ThemeApplyToken += 1
    token := g_ThemeApplyToken
    ThemeMode := Mode
    if (Mode = "light") {
        UI_Colors := UI_Colors_Light
    } else {
        UI_Colors := UI_Colors_Dark
    }

    ; 更新下拉菜单画刷（如果下拉菜单已创建）
    UpdateDefaultStartTabDDLBrush()
    UpdateSearchCenterResultLimitDDLBrush()
    ; WebView 前端主题同步（悬浮栏/悬浮球等）；传入 Mode，避免配置页先 Apply 后写 INI 时从磁盘读到旧主题
    try FloatingToolbar_PushThemeToWeb(Mode)
    catch {
    }
    try FloatingBubble_PushThemeToWeb()
    catch {
    }
    try VK_PushThemeToWeb()
    catch {
    }
    try CommandPalette_PushThemeToWeb(Mode)
    catch {
    }
    try SCWV_PushThemeToWeb()
    catch {
    }
    try SelectionSense_HubCapsule_PushThemeToWeb(Mode)
    catch {
    }
    try SetTimer(ThemeApply_RefreshVisibleUi, -120)
    catch {
    }
    try SetTimer((*) => ThemeApply_ClearIfCurrent(token), -500)
    catch {
        g_ThemeApplyInFlight := false
    }
}

ThemeApply_ClearIfCurrent(token := 0) {
    global g_ThemeApplyInFlight, g_ThemeApplyToken
    if (token != 0 && token != g_ThemeApplyToken)
        return
    g_ThemeApplyInFlight := false
}

ThemeApply_IsInProgress() {
    global g_ThemeApplyInFlight
    return !!g_ThemeApplyInFlight
}

ThemeApply_RefreshVisibleUi(*) {
    global g_CP_Visible, g_CP_Ready, g_SCWV_Visible, g_SCWV_Ready
    try {
        if ConfigWebView_HostAlive()
            ConfigWebView_RefocusAfterThemeChange()
    } catch {
    }
    try {
        if (g_CP_Visible && g_CP_Ready)
            CP_NotifyClipboardUpdated()
    } catch {
    }
    try {
        if (g_SCWV_Visible && g_SCWV_Ready)
            SetTimer(SCWV_FocusDeferred, -60)
    } catch {
    }
}

; ===================== 更新默认启动页面下拉菜单画刷 =====================
UpdateDefaultStartTabDDLBrush() {
    global DefaultStartTabDDL_Hwnd, DDLBrush, UI_Colors, ThemeMode

    ; 如果下拉菜单未创建，直接返回
    if (!DefaultStartTabDDL_Hwnd || DefaultStartTabDDL_Hwnd = 0) {
        return
    }

    try {
        ; 根据主题模式设置颜色（使用 html.to.design 风格配色）
        if (ThemeMode = "dark") {
            ColorCode := "0x" . UI_Colors.DDLBg  ; html.to.design 风格背景
        } else {
            ColorCode := "0x" . UI_Colors.DDLBg  ; 亮色模式背景
        }
        RGBColor := Integer(ColorCode)
        ; 交换R和B字节（Windows使用BGR格式）
        R := (RGBColor & 0xFF0000) >> 16
        G := (RGBColor & 0x00FF00) >> 8
        B := RGBColor & 0x0000FF
        BGRColor := (B << 16) | (G << 8) | R

        ; 如果已有画刷，先删除
        if (DDLBrush != 0) {
            try {
                DllCall("gdi32.dll\DeleteObject", "Ptr", DDLBrush)
            } catch as err {
            }
        }
        ; 创建新的实心画刷
        DDLBrush := DllCall("gdi32.dll\CreateSolidBrush", "UInt", BGRColor, "Ptr")

        ; 强制刷新下拉菜单
        try {
            DllCall("user32.dll\InvalidateRect", "Ptr", DefaultStartTabDDL_Hwnd, "Ptr", 0, "Int", 1)
            DllCall("user32.dll\UpdateWindow", "Ptr", DefaultStartTabDDL_Hwnd)
        } catch as err {
        }
    } catch as err {
    }
}

; ===================== 更新搜索中心结果限制下拉菜单画刷 =====================
UpdateSearchCenterResultLimitDDLBrush() {
    global SearchCenterResultLimitDDL_Hwnd, SearchCenterResultLimitDDL_ListHwnd, SearchCenterResultLimitDDLBrush

    ; 如果下拉菜单未创建，直接返回
    if (!SearchCenterResultLimitDDL_Hwnd || SearchCenterResultLimitDDL_Hwnd = 0) {
        return
    }

    try {
        ; 搜索中心下拉框固定使用白底，避免暗色主题下弹层出现黑块
        ColorCode := "0xFFFFFF"
        RGBColor := Integer(ColorCode)
        ; 交换R和B字节（Windows使用BGR格式）
        R := (RGBColor & 0xFF0000) >> 16
        G := (RGBColor & 0x00FF00) >> 8
        B := RGBColor & 0x0000FF
        BGRColor := (B << 16) | (G << 8) | R

        ; 如果已有画刷，先删除
        if (SearchCenterResultLimitDDLBrush != 0) {
            try {
                DllCall("gdi32.dll\DeleteObject", "Ptr", SearchCenterResultLimitDDLBrush)
            } catch as err {
            }
        }
        ; 创建新的实心画刷
        SearchCenterResultLimitDDLBrush := DllCall("gdi32.dll\CreateSolidBrush", "UInt", BGRColor, "Ptr")

        ; 强制刷新下拉菜单
        try {
            DllCall("user32.dll\InvalidateRect", "Ptr", SearchCenterResultLimitDDL_Hwnd, "Ptr", 0, "Int", 1)
            DllCall("user32.dll\UpdateWindow", "Ptr", SearchCenterResultLimitDDL_Hwnd)
        } catch as err {
        }
    } catch as err {
    }
}

CleanupSearchCenterResultLimitDDLBrush() {
    global SearchCenterResultLimitDDLBrush, SearchCenterResultLimitDDL_Hwnd, SearchCenterResultLimitDDL_ListHwnd

    try {
        if (SearchCenterResultLimitDDLBrush != 0) {
            DllCall("gdi32.dll\DeleteObject", "Ptr", SearchCenterResultLimitDDLBrush)
            SearchCenterResultLimitDDLBrush := 0
        }
    } catch as err {
    }

    SearchCenterResultLimitDDL_Hwnd := 0
    SearchCenterResultLimitDDL_ListHwnd := 0
}

; ===================== 颜色混合辅助函数（模拟透明度效果）====================
BlendColor(Color1, Color2, Ratio) {
    ; 将十六进制颜色转换为 RGB（处理可能的格式）
    ; 确保颜色字符串长度为6
    if (StrLen(Color1) != 6) {
        Color1 := SubStr(Color1, -6)  ; 取最后6位
    }
    if (StrLen(Color2) != 6) {
        Color2 := SubStr(Color2, -6)  ; 取最后6位
    }
    
    ; 转换为整数
    R1 := Integer("0x" . SubStr(Color1, 1, 2))
    G1 := Integer("0x" . SubStr(Color1, 3, 2))
    B1 := Integer("0x" . SubStr(Color1, 5, 2))
    
    R2 := Integer("0x" . SubStr(Color2, 1, 2))
    G2 := Integer("0x" . SubStr(Color2, 3, 2))
    B2 := Integer("0x" . SubStr(Color2, 5, 2))
    
    ; 混合颜色
    R := Round(R1 + (R2 - R1) * Ratio)
    G := Round(G1 + (G2 - G1) * Ratio)
    B := Round(B1 + (B2 - B1) * Ratio)
    
    ; 限制范围
    R := (R < 0) ? 0 : ((R > 255) ? 255 : R)
    G := (G < 0) ? 0 : ((G > 255) ? 255 : G)
    B := (B < 0) ? 0 : ((B > 255) ? 255 : B)
    
    ; 转换回十六进制
    RHex := Format("{:02X}", R)
    GHex := Format("{:02X}", G)
    BHex := Format("{:02X}", B)
    
    return RHex . GHex . BHex
}

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
            "clear_selection", "清空选择",
            "clear", "清空",
            "refresh", "刷新",
            "copy_selected", "复制选中",
            "delete_selected", "删除选中",
            "paste_to_cursor", "粘贴到 Cursor",
            "clipboard_hint", "双击项目可复制 | ESC 关闭",
            "clipboard_tab_ctrlc", "Ctrl+C",
            "clipboard_tab_capslockc", "CapsLock+C",
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
            "config_saved", "配置已保存！快捷键已立即生效。",
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
            "capslock_hold_time", "CapsLock 长按时间 (秒):",
            "capslock_hold_time_hint", "长按 CapsLock 达到该时长后显示 VK KeyBinder 快捷键设置界面，松开 CapsLock 后自动隐藏。范围：0.1–5.0 秒，默认 0.5。若已通过托盘打开键盘，松手不会关闭该窗口。",
            "capslock_hold_time_error", "CapsLock 长按时间必须在 0.1 到 5.0 秒之间",
            "ai_wait_time", "AI 响应等待时间 (毫秒):",
            "countdown_delay", "倒计时延迟时间 (秒):",
            "countdown_delay_hint", "设置粘贴操作前的倒计时时长，范围：0.5-10.0 秒，默认：3.0 秒",
            "explain_prompt", "解释代码提示词:",
            "refactor_prompt", "重构代码提示词:",
            "optimize_prompt", "优化代码提示词:",
            "split_hotkey", "分割快捷键:",
            "batch_hotkey", "批量操作快捷键:",
            "hotkey_esc", "关闭面板 (ESC):",
            "hotkey_esc_desc", "当面板显示时，按此键可关闭面板。",
            "hotkey_c", "连续复制 (C):",
            "hotkey_c_desc", "选中文本后按此键，可将内容添加到剪贴板历史记录中，支持连续复制多段内容。",
            "hotkey_v", "合并粘贴 (V):",
            "hotkey_v_desc", "按此键可将所有已复制的内容合并后粘贴到 Cursor 中。",
            "hotkey_x", "剪贴板管理 (X):",
            "hotkey_x_desc", "按此键可打开剪贴板管理面板，查看和管理所有已复制的内容。",
            "hotkey_e", "解释代码 (E):",
            "hotkey_e_desc", "在 Cursor 中选中代码后按此键，AI 会自动解释代码的核心逻辑和功能。",
            "hotkey_r", "重构代码 (R):",
            "hotkey_r_desc", "在 Cursor 中选中代码后按此键，AI 会自动重构代码，优化代码结构。",
            "hotkey_o", "优化代码 (O):",
            "hotkey_o_desc", "在 Cursor 中选中代码后按此键，AI 会分析并优化代码性能。",
            "hotkey_q", "打开配置 (Q):",
            "hotkey_q_desc", "按此键可打开配置面板，进行各种设置。",
            "hotkey_z", "语音输入 (Z):",
            "hotkey_z_desc", "按此键可启动或停止语音输入功能，支持百度输入法和讯飞输入法。",
            "hotkey_f", "语音搜索 (F):",
            "hotkey_f_desc", "按此键可启动语音搜索功能，输入语音后自动打开浏览器搜索。",
            "hotkey_s", "分割代码 (S):",
            "hotkey_s_desc", "在 Cursor 中选中代码后，长按 CapsLock 调出面板，按此键可在代码中插入分割标记，用于标记多个代码片段以便批量处理。",
            "hotkey_b", "批量操作 (B):",
            "hotkey_b_desc", "在 Cursor 中选中代码后，长按 CapsLock 调出面板，按此键可对已标记的所有代码片段执行批量操作（解释/重构/优化）。",
            "hotkey_t", "区域截图 (T):",
            "hotkey_t_desc", "按此键可启动区域截图功能，选择截图区域后，会自动将截图粘贴到 Cursor 输入框。",
            "screenshot_button_text", "📷 粘贴截图",
            "screenshot_paste_success", "截图已粘贴到输入框",
            "screenshot_button_tip", "点击此按钮将截图粘贴到 Cursor 输入框",
            "hotkey_single_char_hint", "（单个字符，默认: {0}）",
            "hotkey_esc_hint", "（特殊键，默认: Esc）",
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
            "theme_mode", "主题模式:",
            "theme_light", "亮色模式",
            "theme_dark", "暗色模式",
            "config_panel_screen", "配置面板显示器:",
            "msgbox_screen", "弹窗显示器:",
            "voice_input_screen", "语音输入法提示显示器:",
            "cursor_panel_screen", "Cursor快捷弹出面板显示器:",
            "clipboard_panel_screen", "剪贴板管理面板显示器:",
            "config_manage", "配置管理:",
            "default_prompt_explain", "解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点",
            "default_prompt_refactor", "重构这段代码，遵循PEP8/行业规范，简化冗余逻辑，添加中文注释，保持功能不变",
            "default_prompt_optimize", "分析这段代码的性能瓶颈（时间/空间复杂度），给出优化方案+对比说明，保留原逻辑可读性",
            "export_config", "导出配置",
            "export_config_desc", "将当前配置保存为INI文件",
            "import_config", "导入配置",
            "import_config_desc", "从INI文件加载配置",
            "export_clipboard", "导出剪贴板",
            "import_clipboard", "导入剪贴板",
            "export_success", "导出成功",
            "import_success", "导入成功",
            "import_failed", "导入失败",
            "confirm_reset", "确定要重置为默认设置吗？这将清除所有自定义配置。",
            "reset_default_desc", "将所有设置重置为默认值",
            "save_config_desc", "保存当前配置并关闭面板",
            "cancel_desc", "关闭配置面板，不保存更改",
            "config_saved", "配置已保存！",
            "voice_input_starting", "正在启动语音输入...",
            "voice_input_active", "🎤 语音输入中",
            "voice_input_paused", "⏸️ 语音输入已暂停",
            "voice_input_hint", "正在录入，请说话...",
            "voice_input_stopping", "正在结束语音输入...",
            "voice_input_sent", "语音输入已发送到 Cursor",
            "voice_input_failed", "语音输入失败",
            "voice_input_no_content", "未检测到语音输入内容",
            "pause", "暂停",
            "resume", "继续",
            "voice_input_detected_baidu", "检测到百度输入法",
            "voice_input_detected_xunfei", "检测到讯飞输入法",
            "voice_input_auto_detect", "自动检测输入法",
            "voice_search_active", "🎤 语音搜索中",
            "voice_search_hint", "正在录入，请说话...",
            "voice_search_sent", "正在打开搜索...",
            "voice_search_failed", "语音搜索失败",
            "voice_search_no_content", "未检测到语音搜索内容",
            "voice_search_title", "语音搜索",
            "voice_search_input_label", "输入内容:",
            "voice_search_button", "搜索",
            "voice_input_start", "○ 启动语音输入",
            "voice_input_active_text", "✓ 语音输入中",
            "auto_load_selected_text", "自动加载选中文本:",
            "auto_update_voice_input", "自动更新语音输入:",
            "auto_start", "开机自启动",
            "auto_start_desc", "开启后，软件将在Windows启动时自动运行",
            "switch_on", "✓ 已开启",
            "switch_off", "○ 已关闭",
            "select_search_engine", "选择搜索引擎:",
            "select_search_engine_title", "选择搜索引擎",
            "select_action", "选择操作",
            "voice_input_content", "语音输入内容:",
            "send_to_cursor", "发送到 Cursor",
            "no_search_engine_selected", "请至少选择一个搜索引擎",
            "search_engines_opened", "已打开 {0} 个搜索引擎",
            "tip", "提示",
            "search_engine_setting", "搜索引擎设置",
            "search_engine_label", "默认搜索引擎:",
            "search_engine_deepseek", "DeepSeek",
            "search_engine_yuanbao", "元宝",
            "search_engine_doubao", "豆包",
            "search_engine_zhipu", "智谱",
            "search_engine_mita", "秘塔",
            "search_engine_wenxin", "文心一言",
            "search_engine_qianwen", "千问",
            "search_engine_kimi", "Kimi",
            "search_engine_perplexity", "Perplexity",
            "search_engine_copilot", "Copilot",
            "search_engine_chatgpt", "ChatGPT",
            "search_engine_grok", "Grok",
            "search_engine_you", "You",
            "search_engine_claude", "Claude",
            "search_engine_monica", "Monica",
            "search_engine_webpilot", "WebPilot",
            ; 学术类搜索引擎
            "search_engine_zhihu", "知乎",
            "search_engine_wechat_article", "微信文章搜索",
            "search_engine_cainiao", "菜鸟编程",
            "search_engine_gitee", "Gitee",
            "search_engine_pubscholar", "PubScholar",
            "search_engine_semantic", "Semantic Scholar",
            "search_engine_baidu_academic", "百度学术",
            "search_engine_bing_academic", "微软必应学术",
            "search_engine_csdn", "CSDN搜索",
            "search_engine_national_library", "国家图书馆",
            "search_engine_chaoxing", "超星发现",
            "search_engine_cnki", "中国知网",
            "search_engine_wechat_reading", "微信读书",
            "search_engine_dada", "哒哒文库",
            "search_engine_patent", "专利检索",
            "search_engine_ip_office", "国家知识产权局",
            "search_engine_dedao", "得到",
            "search_engine_pkmer", "Pkmer知识社区",
            ; 百度类搜索引擎
            "search_engine_baidu", "百度",
            "search_engine_baidu_title", "限定标题搜索",
            "search_engine_baidu_hanyu", "百度汉语",
            "search_engine_baidu_wenku", "百度文库",
            "search_engine_baidu_map", "百度地图",
            "search_engine_baidu_pdf", "限定搜PDF",
            "search_engine_baidu_doc", "限定搜DOC",
            "search_engine_baidu_ppt", "限定搜PPT",
            "search_engine_baidu_xls", "限定搜XLS",
            ; 图片类搜索引擎
            "search_engine_image_aggregate", "搜图聚合搜索",
            "search_engine_iconfont", "搜矢量图标库",
            "search_engine_wenxin_image", "文心一言文生图",
            "search_engine_tiangong_image", "天工文生图",
            "search_engine_yuanbao_image", "元宝AI画图",
            "search_engine_tongyi_image", "通义万相文字作画",
            "search_engine_zhipu_image", "智谱清言AI画图",
            "search_engine_miaohua", "秒画",
            "search_engine_keling", "可灵",
            "search_engine_jimmeng", "即梦AI文生画",
            "search_engine_baidu_image", "百度图库",
            "search_engine_shetu", "摄图网",
            "search_engine_ai_image_lib", "AI图库网站",
            "search_engine_huaban", "花瓣网",
            "search_engine_zcool", "站酷",
            "search_engine_uisdc", "优设网",
            "search_engine_nipic", "昵图网",
            "search_engine_qianku", "千库网",
            "search_engine_qiantu", "千图网",
            "search_engine_zhongtu", "众图网",
            "search_engine_miyuan", "觅元素",
            "search_engine_mizhi", "觅知网",
            "search_engine_icons", "ICONS",
            "search_engine_tuxing", "图行天下",
            "search_engine_xiangsheji", "享设计",
            "search_engine_bing_image", "必应图片",
            "search_engine_google_image", "谷歌图片",
            "search_engine_weibo_image", "微博图片",
            "search_engine_sogou_image", "搜狗图片",
            "search_engine_haosou_image", "好搜图片",
            ; 音频类搜索引擎
            "search_engine_netease_music", "网易云音乐",
            "search_engine_tiangong_music", "天工AI音乐",
            "search_engine_text_to_speech", "文本转语音",
            "search_engine_speech_to_text", "语音转文本",
            "search_engine_shetu_music", "摄图背景音乐",
            "search_engine_qq_music", "QQ音乐",
            "search_engine_kuwo", "酷我音乐",
            "search_engine_kugou", "酷狗音乐",
            "search_engine_qianqian", "千千音乐",
            "search_engine_ximalaya", "喜马拉雅",
            "search_engine_5sing", "5sing原创音乐",
            "search_engine_lossless", "无损音乐吧",
            "search_engine_erling", "耳聆-音效",
            ; 视频类搜索引擎
            "search_engine_douyin", "抖音",
            "search_engine_yuewen", "悦问",
            "search_engine_qingying", "清影-AI生视频",
            "search_engine_tongyi_video", "通义万相视频生成",
            "search_engine_jimmeng_video", "即梦AI视频生成",
            "search_engine_youtube", "YouTube",
            "search_engine_find_lines", "找台词",
            "search_engine_shetu_video", "摄图视频",
            "search_engine_yandex", "Yandex",
            "search_engine_pexels", "Pexels",
            "search_engine_youku", "优酷",
            "search_engine_chanjing", "蝉镜",
            "search_engine_duojia", "度加创作",
            "search_engine_tencent_zhiying", "腾讯智影",
            "search_engine_wansheng", "万兴AI剪辑",
            "search_engine_tencent_video", "腾讯视频",
            "search_engine_iqiyi", "爱奇艺",
            ; 图书类搜索引擎
            "search_engine_duokan", "多看阅读",
            "search_engine_turing", "图灵社区",
            "search_engine_panda_book", "熊猫搜书",
            "search_engine_douban_book", "豆瓣读书",
            "search_engine_lifelong_edu", "终身教育平台",
            "search_engine_verypan", "verypan搜",
            "search_engine_zouddupai", "走读派导航网",
            "search_engine_gd_library", "广东省立中山图书馆",
            "search_engine_pansou", "盘搜",
            "search_engine_zsxq", "知识星球",
            "search_engine_jiumo", "鸠摩搜书",
            "search_engine_weibo_book", "微博",
            ; 比价类搜索引擎
            "search_engine_jd", "京东",
            "search_engine_baidu_procure", "百度爱采购",
            "search_engine_dangdang", "当当",
            "search_engine_1688", "1688",
            "search_engine_taobao", "淘宝",
            "search_engine_tmall", "天猫",
            "search_engine_pinduoduo", "拼多多",
            "search_engine_xianyu", "闲鱼",
            "search_engine_smzdm", "什么值得买",
            "search_engine_yanxuan", "网易严选",
            "search_engine_gaide", "盖得排行",
            "search_engine_suning", "苏宁易购",
            "search_engine_ebay", "eBay",
            "search_engine_amazon", "亚马逊",
            ; 医疗类搜索引擎
            "search_engine_dxy", "丁香园",
            "search_engine_left_doctor", "左手医生AI",
            "search_engine_medisearch", "MediSearch",
            "search_engine_merck", "默沙东诊疗手册",
            "search_engine_aplus_medical", "A+医学百科",
            "search_engine_medical_baike", "医学百科",
            "search_engine_weiyi", "微医",
            "search_engine_medlive", "医脉通",
            "search_engine_xywy", "寻医问药",
            ; 网盘类搜索引擎
            "search_engine_pansoso", "盘搜搜",
            "search_engine_panso", "盘搜Pro",
            "search_engine_xiaomapan", "小码盘",
            "search_engine_dashengpan", "大圣盘",
            "search_engine_miaosou", "秒搜",
            "search_engine_cli_codex", "Codex",
            "search_engine_cli_gemini", "Gemini",
            "search_engine_cli_openclaw", "OpenClaw",
            "search_engine_cli_qwen", "Qwen",
            "search_engine_cli_ollama", "Ollama",
            "search_engine_cli_claude", "Claude",
            "search_engine_cli_deepseek", "DeepSeek",
            "search_engine_cli_kimi", "Kimi",
            "search_engine_cli_zhipu", "智谱",
            "search_engine_cli_copilot", "Copilot",
            "search_category_ai", "AI",
            "search_category_cli", "CLI",
            "search_category_academic", "学术",
            "search_category_baidu", "百度",
            "search_category_image", "图片",
            "search_category_audio", "音频",
            "search_category_video", "视频",
            "search_category_book", "图书",
            "search_category_price", "比价",
            "search_category_medical", "医疗",
            "search_category_cloud", "网盘",
            "search_category_config", "搜索标签",
            "search_category_config_desc", "配置语音搜索面板中显示的标签，只有勾选的标签才会显示",
            "quick_action_config", "快捷操作按钮",
            "quick_action_config_desc", "配置快捷操作面板中的按钮顺序和功能按键（最多5个）",
            "quick_action_button", "按钮 {0}",
            "quick_action_type", "功能类型:",
            "quick_action_hotkey", "快捷键:",
            "quick_action_move_up", "上移",
            "quick_action_move_down", "下移",
            "quick_action_add", "添加按钮",
            "quick_action_remove", "删除",
            "quick_action_type_explain", "解释代码",
            "quick_action_type_refactor", "重构代码",
            "quick_action_type_optimize", "优化代码",
            "quick_action_type_config", "打开配置",
            "quick_action_type_copy", "连续复制",
            "quick_action_type_paste", "合并粘贴",
            "quick_action_type_clipboard", "剪贴板管理",
            "quick_action_type_voice", "语音输入",
            "quick_action_type_split", "分割代码",
            "quick_action_type_batch", "批量操作",
            "quick_action_type_command_palette", "命令面板",
            "quick_action_type_terminal", "新建终端",
            "quick_action_type_global_search", "全局搜索",
            "quick_action_type_explorer", "资源管理器",
            "quick_action_type_source_control", "源代码管理",
            "quick_action_type_extensions", "扩展面板",
            "quick_action_type_browser", "打开浏览器",
            "quick_action_type_settings", "设置面板",
            "quick_action_type_cursor_settings", "Cursor 设置",
            "quick_action_desc_command_palette", "打开命令面板（Ctrl + Shift + P）",
            "quick_action_desc_terminal", "新建终端（Ctrl + Shift + `）",
            "quick_action_desc_global_search", "全局搜索（Ctrl + Shift + F）",
            "quick_action_desc_explorer", "显示资源管理器（Ctrl + Shift + E）",
            "quick_action_desc_source_control", "显示源代码管理（Ctrl + Shift + G）",
            "quick_action_desc_extensions", "显示扩展面板（Ctrl + Shift + X）",
            "quick_action_desc_browser", "打开浏览器（Ctrl + Shift + B）",
            "quick_action_desc_settings", "显示设置面板（Ctrl + Shift + J）",
            "quick_action_desc_cursor_settings", "显示 Cursor 设置面板（Ctrl + ,）",
            "quick_action_max_reached", "最多只能添加5个按钮",
            "quick_action_min_reached", "至少需要保留1个按钮",
            ; Cursor规则相关文本
            "hotkey_main_tab_settings", "快捷键设置",
            "hotkey_main_tab_rules", "Cursor规则",
            "cursor_rules_title", "Cursor 规则配置",
            "cursor_rules_intro", "根据您开发的程序类型，让 AI 更好地理解您的项目需求。💰 省钱：减少无效的 AI 对话，提高效率`n🎯 精准：AI 更准确理解项目需求`n🛡️ 避坑：避免常见错误和代码问题`n📐 垂直：针对特定领域优化建议`n⚡ 效率：快速生成符合规范的代码",
            "cursor_rules_location_title", "📋 复制位置",
            "cursor_rules_location_desc", "在 Cursor 中，按 Ctrl+Shift+P 打开命令面板，输入 'rules' 或 'cursor rules'，选择 'Open Cursor Rules' 打开 .cursorrules 文件，将规则内容粘贴到该文件中。",
            "cursor_rules_usage_title", "💡 使用方法",
            "cursor_rules_usage_desc", "1. 选择下方对应的开发类型标签`n2. 点击「复制规则」按钮`n3. 在 Cursor 中打开 .cursorrules 文件`n4. 粘贴规则内容并保存`n5. 重启 Cursor 使规则生效",
            "cursor_rules_copy_btn", "复制规则",
            "cursor_rules_copied", "规则已复制到剪贴板！",
            "cursor_rules_import_btn", "导入规则",
            "cursor_rules_imported", "规则已导入！",
            "cursor_rules_import_failed", "导入规则失败",
            "cursor_rules_file_not_found", "未找到 Programming Rules.txt 文件",
            "cursor_rules_export_btn", "导出到文件",
            "cursor_rules_exported", "规则已导出到 .cursorrules 文件！",
            "cursor_rules_export_failed", "导出规则失败",
            "cursor_rules_subtab_general", "通用规则",
            "cursor_rules_subtab_web", "网页开发",
            "cursor_rules_subtab_miniprogram", "小程序",
            "cursor_rules_subtab_plugin", "插件",
            "cursor_rules_subtab_android", "安卓App",
            "cursor_rules_subtab_ios", "iOS App",
            "cursor_rules_subtab_python", "Python",
            "cursor_rules_subtab_backend", "后端服务",
            "cursor_rules_content_placeholder", "规则内容待定，请稍后更新..."
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
            "clear_selection", "Clear Selection",
            "clear", "Clear",
            "refresh", "Refresh",
            "copy_selected", "Copy Selected",
            "delete_selected", "Delete Selected",
            "paste_to_cursor", "Paste to Cursor",
            "clipboard_hint", "Double-click to copy | ESC to close",
            "clipboard_tab_ctrlc", "Ctrl+C",
            "clipboard_tab_capslockc", "CapsLock+C",
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
            "countdown_delay", "Countdown Delay (seconds):",
            "countdown_delay_hint", "Set the countdown duration before paste operation, range: 0.5-10.0 seconds, default: 3.0 seconds",
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
            "capslock_hold_time", "CapsLock Hold Time (seconds):",
            "capslock_hold_time_hint", "Hold CapsLock for this long to show the VK KeyBinder shortcut UI; it hides when you release CapsLock. Range: 0.1–5.0 s, default 0.5. If VK was already opened from the tray, releasing CapsLock will not close it.",
            "capslock_hold_time_error", "CapsLock hold time must be between 0.1 and 5.0 seconds",
            "ai_wait_time", "AI Response Wait Time (ms):",
            "explain_prompt", "Explain Code Prompt:",
            "refactor_prompt", "Refactor Code Prompt:",
            "optimize_prompt", "Optimize Code Prompt:",
            "split_hotkey", "Split Hotkey:",
            "batch_hotkey", "Batch Hotkey:",
            "hotkey_esc", "Close Panel (ESC):",
            "hotkey_esc_desc", "Press this key to close the panel when it is displayed.",
            "hotkey_c", "Continuous Copy (C):",
            "hotkey_c_desc", "After selecting text, press this key to add content to clipboard history, supporting continuous copying of multiple segments.",
            "hotkey_v", "Merge Paste (V):",
            "hotkey_v_desc", "Press this key to merge all copied content and paste it into Cursor.",
            "hotkey_x", "Clipboard Manager (X):",
            "hotkey_x_desc", "Press this key to open the clipboard manager panel to view and manage all copied content.",
            "hotkey_e", "Explain Code (E):",
            "hotkey_e_desc", "After selecting code in Cursor, press this key and AI will automatically explain the core logic and functionality of the code.",
            "hotkey_r", "Refactor Code (R):",
            "hotkey_r_desc", "After selecting code in Cursor, press this key and AI will automatically refactor the code and optimize its structure.",
            "hotkey_o", "Optimize Code (O):",
            "hotkey_o_desc", "After selecting code in Cursor, press this key and AI will analyze and optimize code performance.",
            "hotkey_q", "Open Config (Q):",
            "hotkey_q_desc", "Press this key to open the configuration panel for various settings.",
            "hotkey_z", "Voice Input (Z):",
            "hotkey_z_desc", "Press this key to start or stop voice input, supporting Baidu Input and Xunfei Input.",
            "hotkey_f", "Voice Search (F):",
            "hotkey_f_desc", "Press this key to start voice search, automatically open browser search after voice input.",
            "hotkey_s", "Split Code (S):",
            "hotkey_s_desc", "When the panel is displayed, press this key to insert split markers in the code for batch processing.",
            "hotkey_b", "Batch Operation (B):",
            "hotkey_b_desc", "When the panel is displayed, press this key to execute batch operations.",
            "hotkey_t", "Screenshot (T):",
            "hotkey_t_desc", "Press this key to start area screenshot. After selecting the area, the screenshot will be automatically pasted into Cursor's input box.",
            "screenshot_button_text", "📷 Paste Screenshot",
            "screenshot_paste_success", "Screenshot pasted to input box",
            "screenshot_button_tip", "Click this button to paste screenshot to Cursor input box",
            "hotkey_single_char_hint", "(Single character, default: {0})",
            "hotkey_esc_hint", "(Special key, default: Esc)",
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
            "theme_mode", "Theme Mode:",
            "theme_light", "Light Mode",
            "theme_dark", "Dark Mode",
            "config_panel_screen", "Config Panel Display:",
            "msgbox_screen", "Message Box Display:",
            "voice_input_screen", "Voice Input Prompt Display:",
            "cursor_panel_screen", "Cursor Quick Panel Display:",
            "config_manage", "Config Management:",
            "default_prompt_explain", "Explain the core logic, inputs/outputs, and key functions of this code in simple terms. Highlight potential pitfalls.",
            "default_prompt_refactor", "Refactor this code following PEP8/best practices. Simplify redundant logic, add comments, and keep functionality unchanged.",
            "default_prompt_optimize", "Analyze performance bottlenecks (time/space complexity). Provide optimization solutions with comparison. Keep original logic readable.",
            "close_button", "Close",
            "close_button_tip", "Close Panel",
            "export_config", "Export Config",
            "export_config_desc", "Save current configuration as INI file",
            "import_config", "Import Config",
            "import_config_desc", "Load configuration from INI file",
            "export_clipboard", "Export Clipboard",
            "import_clipboard", "Import Clipboard",
            "export_success", "Export Successful",
            "import_success", "Import Successful",
            "import_failed", "Import Failed",
            "confirm_reset", "Are you sure you want to reset to default settings? This will clear all custom configurations.",
            "reset_default_desc", "Reset all settings to default values",
            "save_config_desc", "Save current configuration and close panel",
            "cancel_desc", "Close configuration panel without saving changes",
            "config_saved", "Configuration Saved! Hotkeys are now active.",
            "voice_input_starting", "Starting voice input...",
            "voice_input_active", "🎤 Voice Input Active",
            "voice_input_paused", "⏸️ Voice Input Paused",
            "voice_input_hint", "Recording, please speak...",
            "voice_input_stopping", "Stopping voice input...",
            "voice_input_sent", "Voice input sent to Cursor",
            "voice_input_failed", "Voice input failed",
            "voice_input_no_content", "No voice input content detected",
            "pause", "Pause",
            "resume", "Resume",
            "voice_input_detected_baidu", "Baidu IME detected",
            "voice_input_detected_xunfei", "Xunfei IME detected",
            "voice_input_auto_detect", "Auto detect IME",
            "voice_search_active", "🎤 Voice Search Active",
            "voice_search_hint", "Recording, please speak...",
            "voice_search_sent", "Opening search...",
            "voice_search_failed", "Voice search failed",
            "voice_search_no_content", "No voice search content detected",
            "voice_search_title", "Voice Search",
            "voice_search_input_label", "Input Content:",
            "voice_search_button", "Search",
            "voice_input_start", "○ Start Voice Input",
            "voice_input_active_text", "✓ Voice Input Active",
            "auto_load_selected_text", "Auto Load Selected Text:",
            "auto_update_voice_input", "Auto Update Voice Input:",
            "auto_start", "Auto Start on Boot",
            "auto_start_desc", "Enable to automatically start the software when Windows starts",
            "switch_on", "✓ On",
            "switch_off", "○ Off",
            "select_search_engine", "Select Search Engine:",
            "select_search_engine_title", "Select Search Engine",
            "select_action", "Select Action",
            "voice_input_content", "Voice Input Content:",
            "send_to_cursor", "Send to Cursor",
            "no_search_engine_selected", "Please select at least one search engine",
            "search_engines_opened", "{0} search engines opened",
            "tip", "Tip",
            "search_engine_setting", "Search Engine Settings",
            "search_engine_label", "Default Search Engine:",
            "search_engine_deepseek", "DeepSeek",
            "search_engine_yuanbao", "Yuanbao",
            "search_engine_doubao", "Doubao",
            "search_engine_zhipu", "Zhipu",
            "search_engine_mita", "Mita",
            "search_engine_wenxin", "Wenxin Yiyan",
            "search_engine_qianwen", "Qianwen",
            "search_engine_kimi", "Kimi",
            "search_engine_perplexity", "Perplexity",
            "search_engine_copilot", "Copilot",
            "search_engine_chatgpt", "ChatGPT",
            "search_engine_grok", "Grok",
            "search_engine_you", "You",
            "search_engine_claude", "Claude",
            "search_engine_monica", "Monica",
            "search_engine_webpilot", "WebPilot",
            ; 学术类搜索引擎
            "search_engine_zhihu", "Zhihu",
            "search_engine_wechat_article", "WeChat Article",
            "search_engine_cainiao", "Cainiao Programming",
            "search_engine_gitee", "Gitee",
            "search_engine_pubscholar", "PubScholar",
            "search_engine_semantic", "Semantic Scholar",
            "search_engine_baidu_academic", "Baidu Academic",
            "search_engine_bing_academic", "Bing Academic",
            "search_engine_csdn", "CSDN Search",
            "search_engine_national_library", "National Library",
            "search_engine_chaoxing", "Chaoxing Discovery",
            "search_engine_cnki", "CNKI",
            "search_engine_wechat_reading", "WeChat Reading",
            "search_engine_dada", "Dada Wenku",
            "search_engine_patent", "Patent Search",
            "search_engine_ip_office", "IP Office",
            "search_engine_dedao", "Dedao",
            "search_engine_pkmer", "Pkmer",
            ; 百度类搜索引擎
            "search_engine_baidu", "Baidu",
            "search_engine_baidu_title", "Title Search",
            "search_engine_baidu_hanyu", "Baidu Hanyu",
            "search_engine_baidu_wenku", "Baidu Wenku",
            "search_engine_baidu_map", "Baidu Map",
            "search_engine_baidu_pdf", "PDF Search",
            "search_engine_baidu_doc", "DOC Search",
            "search_engine_baidu_ppt", "PPT Search",
            "search_engine_baidu_xls", "XLS Search",
            ; 图片类搜索引擎
            "search_engine_image_aggregate", "Image Aggregate",
            "search_engine_iconfont", "Icon Font",
            "search_engine_wenxin_image", "Wenxin Image",
            "search_engine_tiangong_image", "Tiangong Image",
            "search_engine_yuanbao_image", "Yuanbao Image",
            "search_engine_tongyi_image", "Tongyi Image",
            "search_engine_zhipu_image", "Zhipu Image",
            "search_engine_miaohua", "Miaohua",
            "search_engine_keling", "Keling",
            "search_engine_jimmeng", "Jimmeng",
            "search_engine_baidu_image", "Baidu Image",
            "search_engine_shetu", "Shetu",
            "search_engine_ai_image_lib", "AI Image Library",
            "search_engine_huaban", "Huaban",
            "search_engine_zcool", "Zcool",
            "search_engine_uisdc", "UISDC",
            "search_engine_nipic", "Nipic",
            "search_engine_qianku", "Qianku",
            "search_engine_qiantu", "Qiantu",
            "search_engine_zhongtu", "Zhongtu",
            "search_engine_miyuan", "Miyuan",
            "search_engine_mizhi", "Mizhi",
            "search_engine_icons", "ICONS",
            "search_engine_tuxing", "Tuxing",
            "search_engine_xiangsheji", "Xiangsheji",
            "search_engine_bing_image", "Bing Image",
            "search_engine_google_image", "Google Image",
            "search_engine_weibo_image", "Weibo Image",
            "search_engine_sogou_image", "Sogou Image",
            "search_engine_haosou_image", "Haosou Image",
            ; 音频类搜索引擎
            "search_engine_netease_music", "NetEase Music",
            "search_engine_tiangong_music", "Tiangong Music",
            "search_engine_text_to_speech", "Text to Speech",
            "search_engine_speech_to_text", "Speech to Text",
            "search_engine_shetu_music", "Shetu Music",
            "search_engine_qq_music", "QQ Music",
            "search_engine_kuwo", "Kuwo",
            "search_engine_kugou", "Kugou",
            "search_engine_qianqian", "Qianqian",
            "search_engine_ximalaya", "Ximalaya",
            "search_engine_5sing", "5sing",
            "search_engine_lossless", "Lossless Music",
            "search_engine_erling", "Erling",
            ; 视频类搜索引擎
            "search_engine_douyin", "Douyin",
            "search_engine_yuewen", "Yuewen",
            "search_engine_qingying", "Qingying",
            "search_engine_tongyi_video", "Tongyi Video",
            "search_engine_jimmeng_video", "Jimmeng Video",
            "search_engine_youtube", "YouTube",
            "search_engine_find_lines", "Find Lines",
            "search_engine_shetu_video", "Shetu Video",
            "search_engine_yandex", "Yandex",
            "search_engine_pexels", "Pexels",
            "search_engine_youku", "Youku",
            "search_engine_chanjing", "Chanjing",
            "search_engine_duojia", "Duojia",
            "search_engine_tencent_zhiying", "Tencent Zhiying",
            "search_engine_wansheng", "Wansheng",
            "search_engine_tencent_video", "Tencent Video",
            "search_engine_iqiyi", "iQiyi",
            ; 图书类搜索引擎
            "search_engine_duokan", "Duokan",
            "search_engine_turing", "Turing",
            "search_engine_panda_book", "Panda Book",
            "search_engine_douban_book", "Douban Book",
            "search_engine_lifelong_edu", "Lifelong Education",
            "search_engine_verypan", "Verypan",
            "search_engine_zouddupai", "Zouddupai",
            "search_engine_gd_library", "GD Library",
            "search_engine_pansou", "Pansou",
            "search_engine_zsxq", "ZSXQ",
            "search_engine_jiumo", "Jiumo",
            "search_engine_weibo_book", "Weibo",
            ; 比价类搜索引擎
            "search_engine_jd", "JD",
            "search_engine_baidu_procure", "Baidu Procure",
            "search_engine_dangdang", "Dangdang",
            "search_engine_1688", "1688",
            "search_engine_taobao", "Taobao",
            "search_engine_tmall", "Tmall",
            "search_engine_pinduoduo", "Pinduoduo",
            "search_engine_xianyu", "Xianyu",
            "search_engine_smzdm", "SMZDM",
            "search_engine_yanxuan", "Yanxuan",
            "search_engine_gaide", "Gaide",
            "search_engine_suning", "Suning",
            "search_engine_ebay", "eBay",
            "search_engine_amazon", "Amazon",
            ; 医疗类搜索引擎
            "search_engine_dxy", "DXY",
            "search_engine_left_doctor", "Left Doctor",
            "search_engine_medisearch", "MediSearch",
            "search_engine_merck", "Merck Manual",
            "search_engine_aplus_medical", "A+ Medical",
            "search_engine_medical_baike", "Medical Baike",
            "search_engine_weiyi", "Weiyi",
            "search_engine_medlive", "Medlive",
            "search_engine_xywy", "XYWY",
            ; 网盘类搜索引擎
            "search_engine_pansoso", "Pansoso",
            "search_engine_panso", "Panso Pro",
            "search_engine_xiaomapan", "Xiaomapan",
            "search_engine_dashengpan", "Dashengpan",
            "search_engine_miaosou", "Miaosou",
            "search_engine_cli_codex", "Codex",
            "search_engine_cli_gemini", "Gemini",
            "search_engine_cli_openclaw", "OpenClaw",
            "search_engine_cli_qwen", "Qwen",
            "search_engine_cli_ollama", "Ollama",
            "search_engine_cli_claude", "Claude",
            "search_engine_cli_deepseek", "DeepSeek",
            "search_engine_cli_kimi", "Kimi",
            "search_engine_cli_zhipu", "Zhipu",
            "search_engine_cli_copilot", "Copilot",
            "search_category_ai", "AI",
            "search_category_cli", "CLI",
            "search_category_academic", "Academic",
            "search_category_baidu", "Baidu",
            "search_category_image", "Image",
            "search_category_audio", "Audio",
            "search_category_video", "Video",
            "search_category_book", "Book",
            "search_category_price", "Price",
            "search_category_medical", "Medical",
            "search_category_cloud", "Cloud",
            "search_category_config", "Search Category Configuration",
            "search_category_config_desc", "Configure which categories are displayed in the voice search panel",
            "quick_action_config", "Quick Action Button Configuration",
            "quick_action_config_desc", "Configure button order and hotkeys in the quick action panel (max 5)",
            "quick_action_button", "Button {0}",
            "quick_action_type", "Action Type:",
            "quick_action_hotkey", "Hotkey:",
            "quick_action_move_up", "Move Up",
            "quick_action_move_down", "Move Down",
            "quick_action_add", "Add Button",
            "quick_action_remove", "Remove",
            "quick_action_type_explain", "Explain Code",
            "quick_action_type_refactor", "Refactor Code",
            "quick_action_type_optimize", "Optimize Code",
            "quick_action_type_config", "Open Config",
            "quick_action_type_copy", "Continuous Copy",
            "quick_action_type_paste", "Merge Paste",
            "quick_action_type_clipboard", "Clipboard Manager",
            "quick_action_type_voice", "Voice Input",
            "quick_action_type_split", "Split Code",
            "quick_action_type_batch", "Batch Operation",
            "quick_action_type_command_palette", "Command Palette",
            "quick_action_type_terminal", "New Terminal",
            "quick_action_type_global_search", "Global Search",
            "quick_action_type_explorer", "Explorer",
            "quick_action_type_source_control", "Source Control",
            "quick_action_type_extensions", "Extensions",
            "quick_action_type_browser", "Open Browser",
            "quick_action_type_settings", "Settings",
            "quick_action_type_cursor_settings", "Cursor Settings",
            "quick_action_desc_command_palette", "Open command palette (Ctrl + Shift + P)",
            "quick_action_desc_terminal", "New terminal (Ctrl + Shift + `)",
            "quick_action_desc_global_search", "Global search (Ctrl + Shift + F)",
            "quick_action_desc_explorer", "Show explorer (Ctrl + Shift + E)",
            "quick_action_desc_source_control", "Show source control (Ctrl + Shift + G)",
            "quick_action_desc_extensions", "Show extensions (Ctrl + Shift + X)",
            "quick_action_desc_browser", "Open browser (Ctrl + Shift + B)",
            "quick_action_desc_settings", "Show settings (Ctrl + Shift + J)",
            "quick_action_desc_cursor_settings", "Show Cursor settings (Ctrl + ,)",
            "quick_action_max_reached", "Maximum 5 buttons allowed",
            "quick_action_min_reached", "At least 1 button required",
            ; Cursor rules related text
            "hotkey_main_tab_settings", "Hotkey Settings",
            "hotkey_main_tab_rules", "Cursor Rules",
            "cursor_rules_title", "Cursor Rules Configuration",
            "cursor_rules_intro", "Copy the corresponding rule content to Cursor's rules file based on your development program type, so that AI can better understand your project requirements.",
            "cursor_rules_location_title", "📋 Copy Location",
            "cursor_rules_location_desc", "In Cursor, press Ctrl+Shift+P to open the command palette, type 'rules' or 'cursor rules', select 'Open Cursor Rules' to open the .cursorrules file, and paste the rule content into that file.",
            "cursor_rules_usage_title", "💡 Usage",
            "cursor_rules_usage_desc", "1. Select the corresponding development type tab below`n2. Click the 'Copy Rules' button`n3. Open the .cursorrules file in Cursor`n4. Paste the rule content and save`n5. Restart Cursor to apply the rules",
            "cursor_rules_copy_btn", "Copy Rules",
            "cursor_rules_copied", "Rules copied to clipboard!",
            "cursor_rules_import_btn", "Import Rules",
            "cursor_rules_imported", "Rules imported!",
            "cursor_rules_import_failed", "Failed to import rules",
            "cursor_rules_file_not_found", "Programming Rules.txt file not found",
            "cursor_rules_export_btn", "Export to File",
            "cursor_rules_exported", "Rules exported to .cursorrules file!",
            "cursor_rules_export_failed", "Failed to export rules",
            "cursor_rules_subtab_general", "General Rules",
            "cursor_rules_subtab_web", "Web Development",
            "cursor_rules_subtab_miniprogram", "Mini Program",
            "cursor_rules_subtab_plugin", "Plugin",
            "cursor_rules_subtab_android", "Android App",
            "cursor_rules_subtab_ios", "iOS App",
            "cursor_rules_subtab_python", "Python",
            "cursor_rules_subtab_backend", "Backend Service",
            "cursor_rules_content_placeholder", "Rule content pending, please update later..."
        )
    )
    
    ; 兜底：自动执行尚未跑到后部 global Language 时，避免未赋值/空串
    if !IsSet(Language) || Language = ""
        Language := "zh"
    ; 获取当前语言的文本
    if (!Texts.Has(Language)) {
        Language := "zh"  ; 默认使用中文
    }
    LangTexts := Texts[Language]
    
    ; 检查键是否存在
    if (!LangTexts.Has(Key)) {
        return Key  ; 如果找不到，返回键名
    }
    
    Text := LangTexts[Key]
    
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

; ===================== 提示词模板系统 =====================
; 初始化分类定义
InitCategoryDefinitions() {
    global FunctionCategories, SeriesCategories, Language
    IsZh := (Language = "zh")
    
    ; 功能分类定义（一级分类）
    FunctionCategories := Map()
    FunctionCategories["Explain"] := {Name: IsZh ? "解释" : "Explain", SortWeight: 1}
    FunctionCategories["Refactor"] := {Name: IsZh ? "重构" : "Refactor", SortWeight: 2}
    FunctionCategories["Optimize"] := {Name: IsZh ? "优化" : "Optimize", SortWeight: 3}
    
    ; 模板系列定义（二级分类）
    SeriesCategories := Map()
    SeriesCategories["Basic"] := {Name: IsZh ? "基础" : "Basic", SortWeight: 1}
    SeriesCategories["Professional"] := {Name: IsZh ? "专业" : "Professional", SortWeight: 2}
    SeriesCategories["BugFix"] := {Name: IsZh ? "改错" : "BugFix", SortWeight: 3}
    SeriesCategories["Custom"] := {Name: IsZh ? "自定义" : "Custom", SortWeight: 99}
}

; 构建双层分类索引
BuildCategoryMap() {
    global PromptTemplates, CategoryMap, FunctionCategories, SeriesCategories, CategoryMapDirty
    
    ; 🚀 性能优化：如果缓存有效，直接返回
    if (!CategoryMapDirty) {
        return
    }
    
    ; 初始化分类映射
    CategoryMap := Map()
    for FuncCatID, FuncCatInfo in FunctionCategories {
        CategoryMap[FuncCatID] := Map()
        for SeriesID, SeriesInfo in SeriesCategories {
            CategoryMap[FuncCatID][SeriesID] := []
        }
    }
    
    ; 遍历所有模板，分配到对应的分类
    for Index, Template in PromptTemplates {
        ; 获取功能分类（FunctionCategory字段，如果没有则从ID推断）
        FuncCatID := Template.HasProp("FunctionCategory") ? Template.FunctionCategory : InferFunctionCategory(Template)
        
        ; 获取模板系列（Series字段，如果没有则从Category推断）
        SeriesID := Template.HasProp("Series") ? Template.Series : InferSeries(Template)
        
        ; 确保功能分类存在
        if (!CategoryMap.Has(FuncCatID)) {
            CategoryMap[FuncCatID] := Map()
        }
        
        ; 确保模板系列存在
        if (!CategoryMap[FuncCatID].Has(SeriesID)) {
            CategoryMap[FuncCatID][SeriesID] := []
        }
        
        ; 添加到对应分类
        CategoryMap[FuncCatID][SeriesID].Push(Template)
    }
    
    ; 🚀 性能优化：标记缓存有效
    CategoryMapDirty := false
}

; ===================== 重建模板索引（性能优化） =====================
; 构建快速查找索引：ID -> Template, Category|Title -> Template
RebuildTemplateIndex() {
    global PromptTemplates, TemplateIndexByID, TemplateIndexByTitle, TemplateIndexByArrayIndex
    
    ; 清空旧索引
    TemplateIndexByID := Map()
    TemplateIndexByTitle := Map()
    TemplateIndexByArrayIndex := Map()
    
    ; 构建新索引 - O(n)，但只执行一次
    for Index, Template in PromptTemplates {
        ; ID 索引
        TemplateIndexByID[Template.ID] := Template
        
        ; Category+Title 复合索引
        Key := Template.Category . "|" . Template.Title
        TemplateIndexByTitle[Key] := Template
        
        ; 数组索引映射
        TemplateIndexByArrayIndex[Template.ID] := Index
    }
}

; ===================== 标记缓存失效（性能优化） =====================
; 在模板变更时调用，标记分类映射和索引需要重建
InvalidateTemplateCache() {
    global CategoryMapDirty
    CategoryMapDirty := true
    ; 重建索引
    RebuildTemplateIndex()
}

; 从模板ID推断功能分类
InferFunctionCategory(Template) {
    ID := Template.ID
    if (InStr(ID, "explain") || InStr(ID, "Explain")) {
        return "Explain"
    } else if (InStr(ID, "refactor") || InStr(ID, "Refactor")) {
        return "Refactor"
    } else if (InStr(ID, "optimize") || InStr(ID, "Optimize")) {
        return "Optimize"
    } else {
        ; 默认归类到Explain
        return "Explain"
    }
}

; 从模板Category推断模板系列
InferSeries(Template) {
    Category := Template.Category
    if (!Category) {
        Category := ""
    }
    
    ; 中文匹配
    if (Category = "基础" || Category = "Basic") {
        return "Basic"
    } else if (Category = "专业" || Category = "Professional") {
        return "Professional"
    } else if (Category = "改错" || Category = "BugFix") {
        return "BugFix"
    } else {
        ; 其他归类到自定义
        return "Custom"
    }
}

; 创建默认模板
CreateDefaultPromptTemplates() {
    global Language
    IsZh := (Language = "zh")
    
    Templates := []
    
    ; ========== 基础系列 - 解释功能 ==========
    Templates.Push({
        ID: "explain_basic",
        Title: IsZh ? "代码解释" : "Explain Code",
        Content: IsZh ? "解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点" : "Explain the core logic, inputs/outputs, and key functions of this code in simple terms. Highlight potential pitfalls.",
        Icon: "",
        FunctionCategory: "Explain",
        Series: "Basic",
        Category: IsZh ? "基础" : "Basic"  ; 保留用于兼容
    })
    
    ; ========== 基础系列 - 重构功能 ==========
    Templates.Push({
        ID: "refactor_basic",
        Title: IsZh ? "代码重构" : "Refactor Code",
        Content: IsZh ? "重构这段代码，遵循PEP8/行业规范，简化冗余逻辑，添加中文注释，保持功能不变" : "Refactor this code following PEP8/best practices. Simplify redundant logic, add comments, and keep functionality unchanged.",
        Icon: "",
        FunctionCategory: "Refactor",
        Series: "Basic",
        Category: IsZh ? "基础" : "Basic"  ; 保留用于兼容
    })
    
    ; ========== 基础系列 - 优化功能 ==========
    Templates.Push({
        ID: "optimize_basic",
        Title: IsZh ? "性能优化" : "Optimize Code",
        Content: IsZh ? "分析这段代码的性能瓶颈（时间/空间复杂度），给出优化方案+对比说明，保留原逻辑可读性" : "Analyze performance bottlenecks (time/space complexity). Provide optimization solutions with comparison. Keep original logic readable.",
        Icon: "",
        FunctionCategory: "Optimize",
        Series: "Basic",
        Category: IsZh ? "基础" : "Basic"  ; 保留用于兼容
    })
    
    Templates.Push({
        ID: "debug_basic",
        Title: IsZh ? "调试代码" : "Debug Code",
        Content: IsZh ? "请帮我调试这段代码，找出可能的bug和错误，并提供修复建议" : "Please help me debug this code, find potential bugs and errors, and provide fix suggestions.",
        Icon: "",
        Category: IsZh ? "基础" : "Basic"
    })
    
    Templates.Push({
        ID: "test_basic",
        Title: IsZh ? "编写测试" : "Write Tests",
        Content: IsZh ? "为这段代码编写单元测试，覆盖主要功能和边界情况" : "Write unit tests for this code, covering main functionality and edge cases.",
        Icon: "",
        Category: IsZh ? "基础" : "Basic"
    })
    
    Templates.Push({
        ID: "document_basic",
        Title: IsZh ? "添加文档" : "Add Documentation",
        Content: IsZh ? "为这段代码添加详细的文档注释，包括函数说明、参数说明、返回值说明和使用示例" : "Add detailed documentation comments to this code, including function descriptions, parameter descriptions, return value descriptions, and usage examples.",
        Icon: "",
        Category: IsZh ? "基础" : "Basic"
    })
    
    ; ========== 专业分类 ==========
    Templates.Push({
        ID: "code_review",
        Title: IsZh ? "代码审查" : "Code Review",
        Content: IsZh ? "请对这段代码进行全面审查，指出潜在问题、bug、安全隐患和改进建议" : "Review this code comprehensively. Point out potential issues, bugs, security vulnerabilities, and improvement suggestions.",
        Icon: "",
        Category: IsZh ? "专业" : "Professional"
    })
    
    Templates.Push({
        ID: "architecture_analysis",
        Title: IsZh ? "架构分析" : "Architecture Analysis",
        Content: IsZh ? "请从专业的角度分析这段代码，包括架构设计、设计模式、技术选型等方面的考量" : "Analyze this code from a professional perspective, including architectural design, design patterns, and technical choices.",
        Icon: "",
        Category: IsZh ? "专业" : "Professional"
    })
    
    Templates.Push({
        ID: "security_audit",
        Title: IsZh ? "安全审计" : "Security Audit",
        Content: IsZh ? "请对这段代码进行安全审计，检查是否存在SQL注入、XSS、CSRF等安全漏洞，并提供安全加固建议" : "Perform a security audit on this code, check for security vulnerabilities such as SQL injection, XSS, CSRF, and provide security hardening suggestions.",
        Icon: "",
        Category: IsZh ? "专业" : "Professional"
    })
    
    Templates.Push({
        ID: "performance_profiling",
        Title: IsZh ? "性能分析" : "Performance Profiling",
        Content: IsZh ? "请深入分析这段代码的性能问题，包括CPU使用、内存占用、I/O操作等，并提供详细的性能优化方案" : "Deeply analyze the performance issues of this code, including CPU usage, memory consumption, I/O operations, and provide detailed performance optimization solutions.",
        Icon: "",
        Category: IsZh ? "专业" : "Professional"
    })
    
    Templates.Push({
        ID: "design_pattern",
        Title: IsZh ? "设计模式" : "Design Pattern",
        Content: IsZh ? "请分析这段代码是否适合应用设计模式，如果适合，请重构代码应用合适的设计模式，并说明原因" : "Analyze whether this code is suitable for applying design patterns. If suitable, refactor the code to apply appropriate design patterns and explain the reasons.",
        Icon: "",
        Category: IsZh ? "专业" : "Professional"
    })
    
    Templates.Push({
        ID: "scalability",
        Title: IsZh ? "可扩展性分析" : "Scalability Analysis",
        Content: IsZh ? "请分析这段代码的可扩展性，包括如何处理高并发、大数据量等情况，并提供扩展性改进方案" : "Analyze the scalability of this code, including how to handle high concurrency, large data volumes, and provide scalability improvement solutions.",
        Icon: "",
        Category: IsZh ? "专业" : "Professional"
    })
    
    ; ========== 改错分类 ==========
    Templates.Push({
        ID: "bugfix_urgent",
        Title: "不分等着过年？",
        Content: "现在请你扮演一位经验丰富、以严谨著称的架构师。指出现在可能存在的风险、不足或考虑不周的地方，重新审查我们刚才制定的这个 Bug 修复方案 ，请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_multiple",
        Title: "AI海王手册",
        Content: "请提供三种不同的修复方案。并为每种方案说明其优点、缺点和适用场景，让我来做选择，请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_research",
        Title: "上外网看看吧",
        Content: "我的代码遇到了一个典型问题：请你扮演网络搜索助手，在GitHub Issues / Stack Overflow等开源社区汇总常见的解决方案，并针对我的这个bug给出最优的修复建议。请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_explain",
        Title: "给我翻译翻译",
        Content: "请用最简单易懂的语言告诉我这个错误是什么意思？最可能是我代码中的哪部分导致的？请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_diagram",
        Title: "无图无真相",
        Content: "请你为我分别生成 ASCII 序列图或mermaid流程图，模拟展示错误代码的执行步骤和关键变量的变化，帮我直观地看到问题出在哪一步。请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_rules",
        Title: "乱拳打死老师傅",
        Content: "我的代码违反了编程基础规则导致bug，请帮我用「规则校验法」排查：`n1. 列出代码违反的核心编程规则（比如「变量命名规范」「条件判断完整性」「资源释放规则」）；`n2. 用ASCII checklist（勾选框）标注每个规则的违反情况；`n3. 解释这些规则的作用，以及违反后为什么会触发bug；`n4. 给出符合规则的修改思路，附带新手易记的规则口诀。请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_reverse",
        Title: "倒反天罡",
        Content: "从最终的这个 错误结果 / 异常状态开始，进行逆向逻辑推导。分析：在什么情况下、输入了什么样的数据、经过了怎样的操作，才会导致产生这个特定的结果？列出导致该结果的 3 种最可能的根本原因。请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_debug",
        Title: "捉奸拿赃",
        Content: "给我提供一个图形弹窗方案，通过步骤来一步步追溯问题来源，定位问题所在。请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_simple",
        Title: "弱智吧",
        Content: "请用生活中的最简单多类比来解释这个 Bug 的成因。在我不理解任何编程术语的前提下，告诉我这个问题到底在'犯什么傻'。请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_isolate",
        Title: "拆东墙补西墙",
        Content: "把这段代码想象成乐高积木。请告诉我哪几块积木是独立的？请帮我通过'拆除法'定位到底是哪一块积木坏了？请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_color",
        Title: "给点color看看",
        Content: "请给我的代码涂色。绿色是确认安全的，黄色是逻辑可疑的，红色是报错核心。请重点解释红色部分的'逻辑死结'是如何形成的。请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_minimal",
        Title: "Word很大，你忍一下",
        Content: "不要大改我的架构。请给出一种'微创手术'方案：只修改最少的字符（比如改个符号或加个判断），就能让整个程序恢复运行，并解释为什么这一刀最关键。请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_human",
        Title: "请说人话",
        Content: "请提供一份双语对照表。左边是代码行，右边是对应的'人类意图'。通过对比，帮我定位哪一行有错误。请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    return Templates
}

; 加载提示词模板
LoadPromptTemplates() {
    global PromptTemplates, PromptTemplatesFile, DefaultTemplateIDs, Language
    
    ; 初始化分类定义
    InitCategoryDefinitions()
    
    ; 先创建默认模板
    PromptTemplates := CreateDefaultPromptTemplates()
    
    ; 从INI文件加载自定义模板
    if (FileExist(PromptTemplatesFile)) {
        try {
            ; 读取模板数量
            TemplateCount := Integer(IniRead(PromptTemplatesFile, "Templates", "Count", "0"))
            if (TemplateCount > 0) {
                Loop TemplateCount {
                    Index := A_Index
                    TemplateID := IniRead(PromptTemplatesFile, "Template" . Index, "ID", "")
                    if (TemplateID != "") {
                        ; 🚀 性能优化：使用索引查找 - O(1)
                        global TemplateIndexByID
                        if (TemplateIndexByID.Has(TemplateID)) {
                            ; 更新现有模板
                            Template := TemplateIndexByID[TemplateID]
                            Template.Title := IniRead(PromptTemplatesFile, "Template" . Index, "Title", Template.Title)
                            Template.Content := IniRead(PromptTemplatesFile, "Template" . Index, "Content", Template.Content)
                            Template.Icon := IniRead(PromptTemplatesFile, "Template" . Index, "Icon", Template.Icon)
                            Template.Category := IniRead(PromptTemplatesFile, "Template" . Index, "Category", Template.Category)
                            ; 更新索引
                            TemplateIndexByID[TemplateID] := Template
                            global TemplateIndexByTitle
                            Key := Template.Category . "|" . Template.Title
                            TemplateIndexByTitle[Key] := Template
                        } else {
                            ; 添加新模板
                            NewTemplate := {
                                ID: TemplateID,
                                Title: IniRead(PromptTemplatesFile, "Template" . Index, "Title", ""),
                                Content: IniRead(PromptTemplatesFile, "Template" . Index, "Content", ""),
                                Icon: IniRead(PromptTemplatesFile, "Template" . Index, "Icon", "📝"),
                                Category: IniRead(PromptTemplatesFile, "Template" . Index, "Category", "自定义")
                            }
                            PromptTemplates.Push(NewTemplate)
                            ; 🚀 性能优化：更新索引
                            TemplateIndexByID[TemplateID] := NewTemplate
                            Key := NewTemplate.Category . "|" . NewTemplate.Title
                            TemplateIndexByTitle[Key] := NewTemplate
                            global TemplateIndexByArrayIndex
                            TemplateIndexByArrayIndex[TemplateID] := PromptTemplates.Length
                        }
                    }
                }
            }
        } catch as err {
            ; 加载失败，使用默认模板
        }
    }
    
    ; 初始化默认模板映射
    DefaultTemplateIDs["Explain"] := IniRead(PromptTemplatesFile, "Defaults", "Explain", "explain_basic")
    DefaultTemplateIDs["Refactor"] := IniRead(PromptTemplatesFile, "Defaults", "Refactor", "refactor_basic")
    DefaultTemplateIDs["Optimize"] := IniRead(PromptTemplatesFile, "Defaults", "Optimize", "optimize_basic")
    
    ; 构建双层分类索引
    BuildCategoryMap()
    
    ; 🚀 性能优化：重建模板索引
    RebuildTemplateIndex()
    
    ; 加载分类展开状态（从配置文件）
    global CategoryExpandedState
    CategoryExpandedState := Map()
    try {
        ; 读取展开状态数量
        ExpandedStateCount := Integer(IniRead(PromptTemplatesFile, "ExpandedStates", "Count", "0"))
        if (ExpandedStateCount > 0) {
            Loop ExpandedStateCount {
                Index := A_Index
                CategoryName := IniRead(PromptTemplatesFile, "ExpandedState" . Index, "Category", "")
                TemplateKey := IniRead(PromptTemplatesFile, "ExpandedState" . Index, "TemplateKey", "")
                if (CategoryName != "" && TemplateKey != "") {
                    CategoryExpandedState[CategoryName] := TemplateKey
                }
            }
        }
    } catch as err {
        ; 加载失败，使用空的展开状态
        CategoryExpandedState := Map()
    }
}

; 保存提示词模板
SavePromptTemplates() {
    global PromptTemplates, PromptTemplatesFile, DefaultTemplateIDs
    
    try {
        ; 保存模板数量
        IniWrite(String(PromptTemplates.Length), PromptTemplatesFile, "Templates", "Count")
        
        ; 保存每个模板
        for Index, Template in PromptTemplates {
            SectionName := "Template" . Index
            IniWrite(Template.ID, PromptTemplatesFile, SectionName, "ID")
            IniWrite(Template.Title, PromptTemplatesFile, SectionName, "Title")
            IniWrite(Template.Content, PromptTemplatesFile, SectionName, "Content")
            IniWrite(Template.Icon, PromptTemplatesFile, SectionName, "Icon")
            IniWrite(Template.Category, PromptTemplatesFile, SectionName, "Category")
            
            ; 保存新字段（如果存在）
            if (Template.HasProp("FunctionCategory")) {
                IniWrite(Template.FunctionCategory, PromptTemplatesFile, SectionName, "FunctionCategory")
            }
            if (Template.HasProp("Series")) {
                IniWrite(Template.Series, PromptTemplatesFile, SectionName, "Series")
            }
        }
        
        ; 重新构建索引
        BuildCategoryMap()
        
        ; 🚀 性能优化：重建模板索引
        RebuildTemplateIndex()
        
        ; 保存默认模板映射
        IniWrite(DefaultTemplateIDs["Explain"], PromptTemplatesFile, "Defaults", "Explain")
        IniWrite(DefaultTemplateIDs["Refactor"], PromptTemplatesFile, "Defaults", "Refactor")
        IniWrite(DefaultTemplateIDs["Optimize"], PromptTemplatesFile, "Defaults", "Optimize")
        
        ; 保存分类展开状态
        global CategoryExpandedState
        if (IsSet(CategoryExpandedState) && IsObject(CategoryExpandedState) && CategoryExpandedState.Count > 0) {
            ; 先删除旧的展开状态配置
            ExpandedStateCount := Integer(IniRead(PromptTemplatesFile, "ExpandedStates", "Count", "0"))
            if (ExpandedStateCount > 0) {
                Loop ExpandedStateCount {
                    IniDelete(PromptTemplatesFile, "ExpandedState" . A_Index)
                }
            }
            
            ; 保存新的展开状态
            Index := 0
            for CategoryName, TemplateKey in CategoryExpandedState {
                Index++
                IniWrite(CategoryName, PromptTemplatesFile, "ExpandedState" . Index, "Category")
                IniWrite(TemplateKey, PromptTemplatesFile, "ExpandedState" . Index, "TemplateKey")
            }
            IniWrite(String(Index), PromptTemplatesFile, "ExpandedStates", "Count")
        } else {
            ; 如果没有展开状态，清空配置
            IniWrite("0", PromptTemplatesFile, "ExpandedStates", "Count")
        }
    } catch as e {
        ; 保存失败，忽略错误
    }
    
    ; 同步到数据库
    SyncPromptTemplatesToDB()

    try VK_OnPromptTemplatesSaved()
}

; 根据ID获取模板
GetTemplateByID(TemplateID) {
    global TemplateIndexByID
    
    ; 🚀 性能优化：使用索引直接查找 - O(1)
    if (TemplateIndexByID.Has(TemplateID)) {
        return TemplateIndexByID[TemplateID]
    }
    
    ; 如果索引未初始化，回退到旧方法（向后兼容）
    global PromptTemplates
    for Index, Template in PromptTemplates {
        if (Template.ID = TemplateID) {
            return Template
        }
    }
    return ""
}

; ===================== 初始化剪贴板数据库（Raycast 级架构）=====================
InitClipboardDB() {
    global ClipboardDB, ClipboardDBPath
    
    ; 1. 自动创建目录
    if !DirExist(Nmer_DataDir()) {
        DirCreate(Nmer_DataDir())
    }

    ClipboardDBPath := Nmer_CursorDataDbPath()
    
    ; 2. 检查 sqlite3.dll 是否存在
    DllPath := Nmer_Sqlite3DllPath()
    if (!FileExist(DllPath)) {
        MsgBox("sqlite3.dll 未找到。`n请确保 lib\runtime\sqlite3.dll 存在。", "数据库初始化错误", "IconX")
        ClipboardDB := 0
        return
    }
    
    ; 3. 创建 SQLiteDB 实例并打开数据库
    try {
        ClipboardDB := SQLiteDB()
        if (!ClipboardDB.OpenDB(ClipboardDBPath)) {
            MsgBox("无法打开数据库: " . ClipboardDBPath . "`n错误: " . ClipboardDB.ErrorMsg, "数据库初始化错误", "IconX")
            ClipboardDB := 0
            return
        }
        
        ; 4. 启动 SQL 批处理：统一事务 + 分批退避 + 失败回滚
        ; Content: 文本、代码或本地文件路径
        ; DataType: 分类: Text, Code, Link, Image, File, Email
        ; SourceApp: 程序名 (chrome.exe)
        ; SourceTitle: 窗口标题
        ; SourcePath: 程序完整路径 (用于提取图标)
        ; CharCount: 字符数
        ; WordCount: 词数
        ; Timestamp: 时间戳
        ; MetaData: JSON 格式扩展数据
        ; IsPinned: 收藏/置顶
        ; 曾误将 FTS5 虚拟表 ClipboardHistory 建入 CursorData.db，需先剔除再建普通表
        try {
            tbl := ""
            if (ClipboardDB.GetTable("SELECT sql FROM sqlite_master WHERE name='ClipboardHistory'", &tbl)
                && tbl && tbl.HasProp("Rows") && tbl.Rows.Length > 0 && tbl.Rows[1].Length > 0) {
                ddl := String(tbl.Rows[1][1])
                if InStr(ddl, "fts5")
                    ClipboardDB.Exec("DROP TABLE IF EXISTS ClipboardHistory")
            }
            ClipboardDB.Exec("DROP TABLE IF EXISTS ClipMain")
        } catch {
        }
        startupSql := []
        startupSql.Push("DROP VIEW IF EXISTS v_GlobalSearch")
        startupSql.Push(
            "CREATE TABLE IF NOT EXISTS ClipboardHistory ("
            . "ID INTEGER PRIMARY KEY AUTOINCREMENT, "
            . "Timestamp DATETIME DEFAULT (datetime('now', 'localtime')), "
            . "Content TEXT, "
            . "DataType TEXT, "
            . "SourceApp TEXT, "
            . "SourceTitle TEXT, "
            . "SourcePath TEXT, "
            . "CharCount INTEGER, "
            . "WordCount INTEGER, "
            . "MetaData TEXT, "
            . "IsPinned INTEGER DEFAULT 0)"
        )
        
        ; 5.1. 兼容性处理：如果表已存在但包含 SessionID 或 ItemIndex 字段，记录日志（不删表）
        try {
            ResultTable := ""
            if (ClipboardDB.GetTable("PRAGMA table_info(ClipboardHistory)", &ResultTable)) {
                HasSessionID := false
                HasItemIndex := false
                if (ResultTable && ResultTable.HasProp("Rows")) {
                    for Index, Row in ResultTable.Rows {
                        if (Row.Length > 1 && Row[2] = "SessionID") {  ; Row[2] 是字段名
                            HasSessionID := true
                        }
                        if (Row.Length > 1 && Row[2] = "ItemIndex") {
                            HasItemIndex := true
                        }
                    }
                }
                
                ; 如果存在旧字段，删除它们（SQLite 不支持直接删除列，需要重建表）
                if (HasSessionID || HasItemIndex) {
                    ; 由于 SQLite 不支持 ALTER TABLE DROP COLUMN，这里只记录日志
                    ; 实际删除会在下次 DROP TABLE 时完成
                    try {
                        FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] InitClipboardDB: 检测到旧字段 SessionID/ItemIndex，将在下次重建表时移除`n", A_ScriptDir "\clipboard_debug.log")
                    } catch {
                    }
                }
            }
        } catch as err {
            ; 如果字段检查失败，忽略错误（可能表结构已经是新的）
            try {
                FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] InitClipboardDB: 字段检查异常 - " . err.Message . "`n", A_ScriptDir "\clipboard_debug.log")
            } catch {
            }
        }
        
        ; 6. 全局对象规范：验证 ClipboardDB 已正确初始化
        if (!IsObject(ClipboardDB) || ClipboardDB = 0) {
            ErrorMsg := "ClipboardDB 对象未正确创建"
            if (IsObject(ClipboardDB) && ClipboardDB.HasProp("ErrorMsg")) {
                ErrorMsg .= "`n错误: " . ClipboardDB.ErrorMsg
            }
            MsgBox("数据库初始化失败：" . ErrorMsg, "数据库初始化错误", "IconX")
            ClipboardDB := 0
            return
        }
        
        ; 7. 索引/视图/辅助表也并入同一批处理，减少启动期零散写入
        startupSql.Push("CREATE INDEX IF NOT EXISTS idx_clipboard_timestamp ON ClipboardHistory(Timestamp DESC)")
        startupSql.Push("CREATE INDEX IF NOT EXISTS idx_clipboard_content ON ClipboardHistory(Content COLLATE NOCASE)")
        startupSql.Push("CREATE INDEX IF NOT EXISTS idx_clipboard_datatype ON ClipboardHistory(DataType COLLATE NOCASE)")
        startupSql.Push("CREATE INDEX IF NOT EXISTS idx_clipboard_sourceapp ON ClipboardHistory(SourceApp COLLATE NOCASE)")
        startupSql.Push("CREATE INDEX IF NOT EXISTS idx_clipboard_ispinned ON ClipboardHistory(IsPinned)")
        startupSql.Push("CREATE TABLE IF NOT EXISTS Prompts (ID TEXT PRIMARY KEY, Title TEXT NOT NULL COLLATE NOCASE, Content TEXT NOT NULL, Category TEXT COLLATE NOCASE, Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)")
        startupSql.Push("DROP VIEW IF EXISTS v_GlobalSearch")
        startupSql.Push(
            "CREATE VIEW v_GlobalSearch AS "
            . "SELECT "
            . "  Title, "
            . "  Content, "
            . "  'prompt' AS Source, "
            . "  Timestamp, "
            . "  ID AS OriginalID "
            . "FROM Prompts "
            . "UNION ALL "
            . "SELECT "
            . "  SUBSTR(Content, 1, 100) AS Title, "
            . "  Content, "
            . "  'clipboard' AS Source, "
            . "  Timestamp, "
            . "  CAST(ID AS TEXT) AS OriginalID "
            . "FROM ClipboardHistory"
        )
        startupSql.Push("CREATE INDEX IF NOT EXISTS idx_prompts_title ON Prompts(Title COLLATE NOCASE)")
        startupSql.Push("CREATE INDEX IF NOT EXISTS idx_prompts_content ON Prompts(Content COLLATE NOCASE)")
        startupSql.Push("CREATE INDEX IF NOT EXISTS idx_prompts_category ON Prompts(Category COLLATE NOCASE)")
        batchRes := SqlBatch_Run(ClipboardDB, startupSql, "clipboard_startup_schema", 8, 20)
        try NMER_Log("startup", "sql_batch_done", "label=clipboard_startup_schema batches=" . batchRes["batches"] . " count=" . batchRes["count"])
        
        ; 7.1. SessionID 模式已废弃，不再需要初始化
        
    } catch as e {
        ; 检查是否是类不存在的错误
        if (InStr(e.Message, "SQLiteDB") || InStr(e.Message, "does not contain a recognized action")) {
            MsgBox("Class_SQLiteDB.ahk 类文件未找到或无效。`n请从以下地址下载正确的文件：`nhttps://raw.githubusercontent.com/AHK-just-me/Class_SQLiteDB/master/Sources_v1.1/Class_SQLiteDB.ahk`n`n将文件保存为 Class_SQLiteDB.ahk 并放在脚本同目录下。", "数据库初始化错误", "IconX")
        } else {
            MsgBox("初始化数据库时发生异常: " . e.Message, "数据库初始化错误", "IconX")
        }
        ClipboardDB := 0
    }
}

; ===================== 同步提示词模板到数据库 =====================
SyncPromptTemplatesToDB() {
    global ClipboardDB, PromptTemplates, global_ST
    
    if (!ClipboardDB || ClipboardDB = 0) {
        return
    }
    
    if (!IsSet(PromptTemplates) || PromptTemplates.Length = 0) {
        return
    }
    
    ; 【入口强制释放】在调用 DB.Prepare 之前，必须执行强制释放
    if (IsObject(global_ST) && global_ST.HasProp("Free")) {
        try {
            global_ST.Free()
        } catch as err {
        }
        global_ST := 0
    }
    
    ST := ""
    try {
        ; 使用 INSERT OR REPLACE 来同步模板
        SQL := "INSERT OR REPLACE INTO Prompts (ID, Title, Content, Category, Timestamp) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)"
        
        if (!ClipboardDB.Prepare(SQL, &ST)) {
            return
        }
        
        ; 更新全局句柄
        global_ST := ST
        
        if (!IsObject(ST) || !ST.HasProp("Bind")) {
            return
        }
        
        for Index, Template in PromptTemplates {
            if (!ST.Bind(1, "Text", Template.ID)) {
                continue
            }
            if (!ST.Bind(2, "Text", Template.Title)) {
                continue
            }
            if (!ST.Bind(3, "Text", Template.Content)) {
                continue
            }
            Category := Template.HasProp("Category") ? Template.Category : ""
            if (!ST.Bind(4, "Text", Category)) {
                continue
            }
            
            ST.Step()
            ST.Reset()
        }
    } catch as e {
        ; 错误处理
    } finally {
        ; 【过程保底】无论查询成功还是报错，都在 finally 块中释放句柄
        try {
            if (IsObject(global_ST) && global_ST.HasProp("Free")) {
                global_ST.Free()
            }
            global_ST := 0
        } catch as err {
        }
    }
}

; ===================== 激活方式规范化 =====================
NormalizeAppearanceActivationMode(v) {
    s := Trim(String(v))
    ; bubble = 悬浮球圆圈（滚轮缩小）；hole = GDHO 黑洞模式，二者互不相同
    if (s = "bubble" || s = "hole" || s = "tray" || s = "toolbar")
        return s
    return "toolbar"
}

IsHoleRuntimeEnabledByActivationMode() {
    global AppearanceActivationMode
    return NormalizeAppearanceActivationMode(AppearanceActivationMode) = "hole"
}

global g_ActivationRuntimeToken := 0
global g_HoleRuntimeEnabled := false
global g_ActivationApplyLastMode := ""
global g_ActivationApplyLastTick := 0
global g_ScreenshotSuspendActivationMode := ""
global g_ScreenshotSuspendActivationToken := 0

SetHoleRuntimeEnabled(enabled) {
    global g_HoleRuntimeEnabled
    g_HoleRuntimeEnabled := !!enabled
    if FuncExists("HoleTriggers_SyncInputCapture")
        try HoleTriggers_SyncInputCapture()
    catch {
    }
}

BeginScreenshotUiSession() {
    global g_ScreenshotSuspendActivationMode, g_ScreenshotSuspendActivationToken, AppearanceActivationMode
    if (g_ScreenshotSuspendActivationMode != "")
        return false
    m := NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar")
    if (m != "hole")
        return false
    g_ScreenshotSuspendActivationToken += 1
    g_ScreenshotSuspendActivationMode := m
    try SurfaceManager_ObserveModeTransition("screenshot_suspend_begin", m, Map("token", g_ScreenshotSuspendActivationToken))
    try SetHoleRuntimeEnabled(false)
    catch {
    }
    try NativeDropBridge_Stop()
    catch {
    }
    try GDHO_UnpinFromDesktop()
    catch {
    }
    try GDHO_SetClickThrough(true)
    catch {
    }
    try GDHO_Stop()
    catch {
    }
    return true
}

EndScreenshotUiSession(token := 0) {
    global g_ScreenshotSuspendActivationMode, g_ScreenshotSuspendActivationToken, AppearanceActivationMode
    if (g_ScreenshotSuspendActivationMode = "")
        return false
    if (token = 0)
        token := g_ScreenshotSuspendActivationToken
    if (token != g_ScreenshotSuspendActivationToken)
        return false
    suspendedMode := g_ScreenshotSuspendActivationMode
    g_ScreenshotSuspendActivationMode := ""
    try SurfaceManager_ObserveModeTransition("screenshot_suspend_end", suspendedMode, Map("token", token))
    if (suspendedMode = "hole" && NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar") = "hole") {
        try SetTimer((*) => RestoreActivationRuntimeAfterScreenshot(token), -120)
        catch {
            try RestoreActivationRuntimeAfterScreenshot(token)
            catch {
            }
        }
    }
    return true
}

RestoreActivationRuntimeAfterScreenshot(token) {
    global g_ScreenshotSuspendActivationToken, g_ScreenshotSuspendActivationMode, AppearanceActivationMode
    if (token = 0 || token != g_ScreenshotSuspendActivationToken)
        return false
    if (g_ScreenshotSuspendActivationMode != "")
        return false
    if (NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar") != "hole")
        return false
    try SurfaceManager_ObserveModeTransition("screenshot_restore_runtime", "hole", Map("token", token))
    try ApplyActivationRuntimeAsync("hole")
    catch {
    }
    return true
}

ApplyActivationRuntimeAsync(mode) {
    global g_ActivationRuntimeToken
    g_ActivationRuntimeToken += 1
    tok := g_ActivationRuntimeToken
    try SurfaceManager_ObserveModeTransition("runtime_schedule", NormalizeAppearanceActivationMode(mode), Map("token", tok))
    try SetTimer(ApplyActivationRuntimeDeferred.Bind(mode, tok), -40)
}

ApplyActivationRuntimeDeferred(mode, token) {
    global g_ActivationRuntimeToken
    if (token != g_ActivationRuntimeToken)
        return
    m := NormalizeAppearanceActivationMode(mode)
    try SurfaceManager_ObserveModeTransition("runtime_begin", m, Map("token", token))
    NMER_Log("activation", "runtime_deferred", "mode=" . m . " token=" . token)
    t0 := A_TickCount
    ; 切换激活模式时统一清理残留的 CapsLock 物理/逻辑状态，避免重启或黑洞切换后
    ; 继续沿用上一次会话里的“按下中”状态，导致单键被误判成 CapsLock+组合键。
    try NormalizeCapsLockRuntimeForUiOpen()
    catch {
    }
    if (m = "hole") {
        try SetHoleRuntimeEnabled(true)
        try {
            localHole := GDHO_BuildFileUrl(HtmlPanelPath("hole_starry.html"))
            if FileExist(HtmlPanelPath("hole_starry.html")) {
                GDHO_SetPageUrl(localHole)
                GDHO_SetFallbackUrl(localHole)
            }
            if (IsSet(GDHO_DECOUPLED_TOPOLOGY) && GDHO_DECOUPLED_TOPOLOGY) {
                localPanel := GDHO_BuildFileUrl(HtmlPanelPath("hole_panel.html"))
                if FileExist(HtmlPanelPath("hole_panel.html")) {
                    GDHO_SetPanelPageUrl(localPanel)
                    GDHO_SetPanelFallbackUrl(localPanel)
                }
                if FileExist(HtmlPanelPath("hole_launcher_layer.html")) {
                    if FuncExists("GDHO_SetLauncherFallbackUrl")
                        try GDHO_SetLauncherFallbackUrl(BuildAppLocalUrl("hole_launcher_layer.html"))
                }
            }
        } catch {
        }
        try GDHO_Start()
        catch {
        }
        if (FuncExists("GDHO_IsDecoupled") && GDHO_IsDecoupled()) {
            ; 解耦：划选驱动弱预览，切换模式时不钉 file 常驻态（否则会挡住文字黑洞）。
            if FuncExists("GDHO_PrepareDecoupledHoleForTextSelection") {
                try GDHO_PrepareDecoupledHoleForTextSelection("runtime_hole")
            } else {
                try GDHO_UnpinFromDesktop()
                catch {
                }
            }
        } else {
            ; 旧拓扑：常驻钉住 file 黑洞，绕开文本近距门槛。
            try GDHO_PinToDesktop("file")
            catch {
            }
            try GDHO_SetClickThrough(false)
        }
        try NativeDropBridge_Start()
        catch {
        }
        try NativeDropBridge_RestartForHoleDropRect()
        catch {
        }
        try NativeDropBridge_SetSilentMode(false, "runtime_hole")
        catch {
        }
        if FuncExists("HoleTriggers_LoadFromIni")
            try HoleTriggers_LoadFromIni(ConfigFile)
        if FuncExists("HoleTriggers_SyncInputCapture")
            try HoleTriggers_SyncInputCapture()
        NMER_Log("activation", "runtime_hole_ready", "elapsed_ms=" . (A_TickCount - t0))
        try SurfaceManager_ObserveModeTransition("runtime_ready", "hole", Map("token", token, "elapsedMs", A_TickCount - t0))
        return
    }
    if (m = "disabled") {
        try SetHoleRuntimeEnabled(false)
        if FuncExists("HoleTriggers_SyncInputCapture")
            try HoleTriggers_SyncInputCapture()
        try NativeDropBridge_Stop()
        catch {
        }
        try GDHO_Stop()
        catch {
        }
        NMER_Log("activation", "runtime_disabled_ready", "elapsed_ms=" . (A_TickCount - t0))
        try SurfaceManager_ObserveModeTransition("runtime_ready", "disabled", Map("token", token, "elapsedMs", A_TickCount - t0))
        return
    }
    try SetHoleRuntimeEnabled(false)
    try NativeDropBridge_SetSilentMode(true, "runtime_" . m)
    catch {
    }
    try GDHO_UnpinFromDesktop()
    catch {
    }
    try GDHO_SetClickThrough(true)
    catch {
    }
    try GDHO_DisarmPolling("runtime_" . m)
    catch {
    }
    try GDHO_HideFrontend()
    catch {
    }
    try GDHO_HideOverlay()
    catch {
    }
    NMER_Log("activation", "runtime_non_hole_ready", "mode=" . m . " elapsed_ms=" . (A_TickCount - t0))
    try SurfaceManager_ObserveModeTransition("runtime_ready", m, Map("token", token, "elapsedMs", A_TickCount - t0))
}

; 根据「外观 · 激活方式」显示悬浮栏 / 黑洞模式 / 或仅托盘
ApplyAppearanceActivationMode() {
    global AppearanceActivationMode
    global g_ActivationApplyLastMode, g_ActivationApplyLastTick, g_ActivationApplyToken
    m := NormalizeAppearanceActivationMode(AppearanceActivationMode)
    nowTick := A_TickCount
    ; Coalesce duplicate mode applies to avoid toolbar/hole visibility thrash.
    if (m = g_ActivationApplyLastMode && g_ActivationApplyLastTick > 0 && (nowTick - g_ActivationApplyLastTick) < 250)
        return true
    g_ActivationApplyLastMode := m
    g_ActivationApplyLastTick := nowTick
    g_ActivationApplyToken += 1
    token := g_ActivationApplyToken
    try SurfaceManager_ObserveModeTransition("appearance_schedule", m, Map("token", token))
    SetTimer((*) => ApplyAppearanceActivationMode_Run(m, token), -10)
    return true
}

ApplyAppearanceActivationMode_Run(m, token) {
    global g_ActivationApplyToken, g_ActivationApplyInFlight
    if (token != g_ActivationApplyToken)
        return
    g_ActivationApplyInFlight := true
    try SurfaceManager_ObserveModeTransition("appearance_begin", m, Map("token", token))
    try {
        NMER_Log("activation", "apply_mode_begin", "mode=" . m)
        if (m = "toolbar") {
            openNiumaDrawer := false
            try openNiumaDrawer := !!g_FTB_PendingOpenNiumaDrawer
            catch {
                openNiumaDrawer := false
            }
            try ApplyActivationRuntimeAsync("toolbar")
            try FloatingBubble_DestroyCompletely()
            catch {
            }
            if !openNiumaDrawer {
                try FloatingToolbarChatDrawerOpen := false
                catch {
                }
                global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WaitingUiFinishedReveal
                try {
                    if (g_FTB_WV2_Ready && g_FTB_WV2 && !g_FTB_WaitingUiFinishedReveal) {
                        WebView_QueuePayload(g_FTB_WV2, Map("type", "host_force_toolbar_home"))
                    }
                } catch {
                }
            }
            try FloatingToolbar_ShowForActivationMode()
            catch {
                try FloatingToolbar_ForceRecoverVisible()
                catch {
                }
            }
            if !openNiumaDrawer {
                global g_FTB_WV2_Ready, FloatingToolbarIsVisible, g_FTB_WaitingUiFinishedReveal
                if (g_FTB_WV2_Ready && FloatingToolbarIsVisible && !g_FTB_WaitingUiFinishedReveal) {
                    try FloatingToolbarReloadFromToolbarLayout()
                    catch {
                    }
                }
            } else {
                try FloatingToolbar_ScheduleNiumaDrawerOpen(280)
                catch {
                }
                try SetTimer(FloatingToolbar_NiumaDrawerHandoffRetry, -720)
                catch {
                }
            }
            NMER_Log("activation", "apply_mode_toolbar", "ok=1 open_niuma=" . (openNiumaDrawer ? "1" : "0"))
            try SurfaceManager_ObserveModeTransition("appearance_ready", "toolbar", Map("token", token, "openNiumaDrawer", openNiumaDrawer ? 1 : 0))
            return
        }
        if (m = "bubble") {
            try ApplyActivationRuntimeAsync("toolbar")
            try FloatingToolbarChatDrawerOpen := false
            catch {
            }
            try SurfaceIntent_Close("floating_toolbar")
            catch {
            }
            try ShowFloatingBubble()
            catch {
            }
            NMER_Log("activation", "apply_mode_bubble", "ok=1")
            try SurfaceManager_ObserveModeTransition("appearance_ready", "bubble", Map("token", token))
            return
        }
        if (m = "hole") {
            if FuncExists("FloatingToolbar_CancelToolbarRecoveryTimers") {
                try FloatingToolbar_CancelToolbarRecoveryTimers()
                catch {
                }
            }
            try SurfaceIntent_Close("floating_toolbar")
            catch {
            }
            try FloatingBubble_DestroyCompletely()
            catch {
            }
            if FuncExists("GDHO_PrepareDecoupledHoleForTextSelection") {
                try GDHO_PrepareDecoupledHoleForTextSelection("apply_mode_hole")
                catch {
                }
            }
            try ApplyActivationRuntimeAsync("hole")
            NMER_Log("activation", "apply_mode_hole", "ok=1")
            try SurfaceManager_ObserveModeTransition("appearance_ready", "hole", Map("token", token))
            return
        }
        try SurfaceIntent_Close("floating_toolbar")
        catch {
        }
        try FloatingBubble_DestroyCompletely()
        catch {
        }
        NMER_Log("activation", "apply_mode_tray", "ok=1")
        try ApplyActivationRuntimeAsync("tray")
        try SurfaceManager_ObserveModeTransition("appearance_ready", "tray", Map("token", token))
    } finally {
        g_ActivationApplyInFlight := false
    }
}

ActivationApply_IsInProgress() {
    global g_ActivationApplyInFlight
    return !!g_ActivationApplyInFlight
}

; 是否仍处于黑洞激活（勿用 GDHO_VISIBLE：切到 toolbar 后 overlay 可能短暂仍可见，会触发强制切换死循环）
Nmer_IsHoleActivationRuntimeActive() {
    global AppearanceActivationMode, g_HoleRuntimeEnabled
    if (NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar") = "hole")
        return true
    try {
        return !!(IsSet(g_HoleRuntimeEnabled) && g_HoleRuntimeEnabled)
    } catch {
        return false
    }
}

; 托盘/菜单切换激活方式：写 INI + 立即收敛黑洞运行态 + 应用 UI（避免 SetActivationMode 幂等早退）
Nmer_PersistAndApplyActivationMode(mode) {
    global AppearanceActivationMode, ConfigFile, g_ActivationApplyLastMode, g_ActivationApplyLastTick
    static persistInFlight := false
    if persistInFlight
        return NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar")
    persistInFlight := true
    try {
    m := NormalizeAppearanceActivationMode(mode)
    try SurfaceManager_ObserveModeTransition("persist_begin", m)
    if (m != "hole" && FuncExists("FloatingToolbar_CancelReturnToHoleAfterNiuma")) {
        try FloatingToolbar_CancelReturnToHoleAfterNiuma()
        catch {
        }
    }
    AppearanceActivationMode := m
    cfg := (IsSet(ConfigFile) && ConfigFile != "") ? ConfigFile : (A_ScriptDir . "\local\CursorShortcut.ini")
    try IniWrite(m, cfg, "Appearance", "ActivationMode")
    catch {
    }
    g_ActivationApplyLastMode := ""
    g_ActivationApplyLastTick := 0
    if (m != "hole") {
        try SetHoleRuntimeEnabled(false)
        catch {
        }
        try ApplyActivationRuntimeAsync(m)
        catch {
        }
    }
    if (m = "toolbar") {
        try FloatingToolbar_ClearOverlaySuppression()
        catch {
        }
    }
    try ApplyAppearanceActivationMode()
    catch {
    }
    if (m = "toolbar") {
        try SetTimer(FloatingToolbar_ShowForActivationMode, -40)
        catch {
        }
        try SetTimer((*) => FloatingToolbar_ForceRecoverVisible(), -220)
        catch {
        }
    }
    try NMER_Log("activation", "persist_apply", "mode=" . m)
    catch {
    }
    try SurfaceManager_ObserveModeTransition("persist_ready", m)
    if FuncExists("TrayMenu_Log") {
        try TrayMenu_Log("persist_activation_mode mode=" . m)
        catch {
        }
    }
    return m
    } finally {
        persistInFlight := false
    }
}

; 选区/牛马等需要宿主表面已显示时调用：按激活方式打开悬浮栏（黑洞/后台模式不弹出）
EnsureFloatingSurfaceVisible() {
    global AppearanceActivationMode
    m := NormalizeAppearanceActivationMode(AppearanceActivationMode)
    if (m = "toolbar") {
        try FloatingToolbar_ShowForActivationMode()
        catch {
        }
    }
}

; 在InitConfig结束后加载模板
HtmlPanelPath(fileName := "") {
    base := A_ScriptDir . "\html"
    if (Trim(String(fileName)) = "")
        return base
    return base . "\" . fileName
}

BuildAppLocalUrl(relativePath) {
    host := "app.local"
    try {
        if IsSet(UnifiedAssetsHost) {
            h := Trim(String(UnifiedAssetsHost))
            if (h != "")
                host := h
        }
    } catch {
    }
    normalized := StrReplace(relativePath, "\", "/")
    if (SubStr(normalized, 1, 1) = "/")
        normalized := SubStr(normalized, 2)
    qSuffix := ""
    if (iq := InStr(normalized, "?")) {
        qSuffix := SubStr(normalized, iq)
        normalized := SubStr(normalized, 1, iq - 1)
    }
    if (RegExMatch(normalized, "\.html$") && !RegExMatch(normalized, "^(html/|assets/|archive/|tools/|lib/|modules/|aiicons/|assets/icons/|searchcore/|config/|md/)"))
        normalized := "html/" . normalized
    return "https://" . host . "/" . normalized . qSuffix
}

BuildAppAssetUrl(relativePath) {
    normalized := StrReplace(relativePath, "\", "/")
    if (SubStr(normalized, 1, 1) = "/")
        normalized := SubStr(normalized, 2)
    if (SubStr(normalized, 1, 7) = "assets/")
        return BuildAppLocalUrl(normalized)
    return BuildAppLocalUrl("assets/" . normalized)
}

GDHO_ResolveHolePageUrl(fallbackUrl) {
    devUrl := "http://127.0.0.1:5173/hole_starry.html"
    if GDHO_IsHoleUrlReachable(devUrl, 900)
        return devUrl

    ; Try to auto-start Vite dev server for hole page.
    GDHO_TryStartHoleDevServer()
    Loop 18 {
        Sleep(280)
        if GDHO_IsHoleUrlReachable(devUrl, 700)
            return devUrl
    }
    return fallbackUrl
}

GDHO_IsHoleUrlReachable(url, timeoutMs := 800) {
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(timeoutMs, timeoutMs, timeoutMs, timeoutMs)
        req.Open("GET", url, false)
        req.Send()
        st := 0
        try st := Integer(req.Status)
        return (st >= 200 && st < 400)
    } catch {
        return false
    }
}

GDHO_TryStartHoleDevServer() {
    try {
        ; TODO(wails-migration): 迁移后优先 apps\nmer-wails\frontend；保留 archive 路径以兼容本机旧目录。
        workDir := A_ScriptDir . "\archive\prototype\wails-toolbar-app\frontend"
        if !DirExist(workDir)
            return false
        logDir := A_ScriptDir . "\Cache"
        try DirCreate(logDir)
        logFile := logDir . "\hole-vite.log"
        ps := "Set-Location '" . StrReplace(workDir, "'", "''") . "'; npm run dev *> '" . StrReplace(logFile, "'", "''") . "'"
        cmd := '"' . A_ComSpec . '" /c powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "' . ps . '"'
        Run(cmd, , "Hide")
        return true
    } catch {
        return false
    }
}

GDHO_BuildFileUrl(absPath) {
    p := String(absPath)
    p := StrReplace(p, "\", "/")
    ; file:///C:/...
    return "file:///" . p
}

GDHO_LoadSettingsFromIni() {
    global ConfigFile
    if !FileExist(ConfigFile)
        return
    mode := IniRead(ConfigFile, "Appearance", "HolePositionMode", "anchor")
    td := Integer(IniRead(ConfigFile, "Appearance", "HoleTriggerDistance", "260"))
    dd := Integer(IniRead(ConfigFile, "Appearance", "HoleDismissDistance", "320"))
    fx := Integer(IniRead(ConfigFile, "Appearance", "HoleFixedX", "360"))
    fy := Integer(IniRead(ConfigFile, "Appearance", "HoleFixedY", "260"))
    ss := CfgParseFloat(IniRead(ConfigFile, "Appearance", "HoleSizeScale", "1.0"), 1.0)
    al := CfgParseFloat(IniRead(ConfigFile, "Appearance", "HoleAnimLevel", "1.0"), 1.0)
    vs := StrLower(Trim(String(IniRead(ConfigFile, "Appearance", "HoleVisualStyle", "ring"))))
    if (vs != "ring" && vs != "starry")
        vs := "ring"
    hideDockEnabled := (IniRead(ConfigFile, "Appearance", "HoleHideDockEnabled", "1") = "1")
    hideDockEdge := IniRead(ConfigFile, "Appearance", "HoleHideDockEdge", "right")
    hideDockMargin := Integer(IniRead(ConfigFile, "Appearance", "HoleHideDockMargin", "10"))
    try GDHO_SetScreenAnchor(fx, fy)
    try GDHO_ApplySettings(mode, td, dd, fx, fy, ss, al, vs)
    try GDHO_ApplyHideDockSettings(hideDockEnabled, hideDockEdge, hideDockMargin)
    if FuncExists("HoleTriggers_LoadFromIni")
        try HoleTriggers_LoadFromIni(ConfigFile)
    try {
        if (IniRead(ConfigFile, "Appearance", "HoleDecoupledTopology", "1") = "0")
            GDHO_DECOUPLED_TOPOLOGY := false
        else
            GDHO_DECOUPLED_TOPOLOGY := true
    }
    try {
        if (IniRead(ConfigFile, "Appearance", "HoleStarFullscreen", "0") = "1")
            GDHO_STAR_FULLSCREEN := true
        else
            GDHO_STAR_FULLSCREEN := false
    }
    if FuncExists("GDHO_LoadPanelPositionFromIni")
        try GDHO_LoadPanelPositionFromIni()
}

ApplyUnifiedWebViewAssets(wv2) {
    global UnifiedAssetsHost, UnifiedAssetsRoot, UnifiedAssetsAccessKind
    try wv2.SetVirtualHostNameToFolderMapping(UnifiedAssetsHost, UnifiedAssetsRoot, UnifiedAssetsAccessKind)
}

WebView_DumpJson(payload) {
    try return Jxon_Dump(payload)
    catch as err {
        OutputDebug("[WebView] Jxon_Dump failed: " . err.Message)
        return ""
    }
}

WebView_QueueJson(wv2, jsonStr) {
    global WebViewMsgQueue
    if !wv2 || jsonStr = ""
        return
    WebViewMsgQueue.Push(Map("wv2", wv2, "json", jsonStr))
    _WebView_QueueKick()
}

WebView_QueuePayload(wv2, payload) {
    global WebViewMsgQueue
    if !wv2
        return
    WebViewMsgQueue.Push(Map("wv2", wv2, "payload", payload))
    _WebView_QueueKick()
}

_WebView_QueueKick() {
    global WebViewMsgQueueActive
    if WebViewMsgQueueActive
        return
    WebViewMsgQueueActive := true
    SetTimer(_WebView_QueueFlush, -10)
}

_WebView_QueueFlush(*) {
    global WebViewMsgQueue, WebViewMsgQueueActive
    if (WebViewMsgQueue.Length = 0) {
        WebViewMsgQueueActive := false
        return
    }
    item := WebViewMsgQueue.RemoveAt(1)
    jsonStr := ""
    if (item.Has("json")) {
        jsonStr := item["json"]
    } else if (item.Has("payload")) {
        jsonStr := WebView_DumpJson(item["payload"])
    }
    if (jsonStr != "") {
        try {
            if IsObject(item["wv2"])
                item["wv2"].PostWebMessageAsJson(jsonStr)
        } catch as e {
            try {
                ; 这里是宿主->WebView 的关键通道；失败必须可见，否则前端只能超时
                snippet := SubStr(String(jsonStr), 1, 260)
                OutputDebug("[WebView] PostWebMessageAsJson failed: " . e.Message . " | json_head=" . snippet)
            } catch {
            }
        }
    }
    SetTimer(_WebView_QueueFlush, -10)
}

_WarmupConfigWebView(*) {
    global UseWebViewSettings
    try SurfaceManager_ObserveWarmupStep(WebViewWarmupIndex + 1, Func("_WarmupConfigWebView"))
    if !UseWebViewSettings
        return
    if !SurfaceManager_ShouldWarmupConfig() {
        try SurfaceManager_RecordEvent("warmup_skip", "config_webview", Map("reason", "interceptWarmup_enabled"))
        return
    }
    try SurfaceManager_ObserveInit("config_webview", Map("source", "warmup"))
    try ConfigWebView_CreateHost()
}

_RunWebViewWarmupStep(*) {
    global WebViewWarmupQueue, WebViewWarmupIndex
    if (WebViewWarmupIndex >= WebViewWarmupQueue.Length)
        return

    WebViewWarmupIndex += 1
    initFn := WebViewWarmupQueue[WebViewWarmupIndex]
    try SurfaceManager_ObserveWarmupStep(WebViewWarmupIndex, initFn)
    try initFn.Call()

    if (WebViewWarmupIndex < WebViewWarmupQueue.Length)
        SetTimer(_RunWebViewWarmupStep, -350)
}

_WV2_BeginWarmupAfterEnv(*) {
    ; 共享 Environment 已就绪后再显示悬浮栏/球，避免启动首屏与 EnsureSharedEnvBlocking 竞态导致卡死或 WebView2 崩溃
    try ApplyAppearanceActivationMode()
    catch as _eApp {
    }
    ; Runtime mode switch async/coalesced to keep startup and settings transitions smooth.
    try ApplyActivationRuntimeAsync(NormalizeAppearanceActivationMode(AppearanceActivationMode))
    global WebViewWarmupQueue, WebViewWarmupIndex
    try SurfaceManager_EnsureBootstrap()
    WebViewWarmupIndex := 0
    WebViewWarmupQueue := SurfaceManager_BuildWarmupQueue([CP_Init, PQP_Init, SCWV_Init, VK_EnsureInit.Bind(true)])
    try SurfaceManager_ObserveWarmupQueue(WebViewWarmupQueue)
    SetTimer(_RunWebViewWarmupStep, -10)
    SetTimer(_WarmupConfigWebView, -5000)
    if FuncExists("Nmer_AutoStartSearchCenterCore")
        SetTimer(Nmer_AutoStartSearchCenterCore, -1200)
    ; interceptWarmup 下搜索中心不进入 warmup 队列，改为悬浮栏就绪后后台预热隐藏宿主。
    if FuncExists("SCWV_ScheduleIdlePrewarm")
        SetTimer((*) => SCWV_ScheduleIdlePrewarm(8000), -4000)
}

NativeDropBridge_Start() {
    global EnableNativeDropBridge, NativeDropBridgePID, NativeDropBridgeExe, NativeDropBridgeOut, NativeDropBridgeReadOffset
    global NativeDropBridgeUseCopyData, NativeDropBridgeCopyDataReady, NativeDropBridgeCopyDataTitle
    global NativeDropBridgeStartTick, NativeDropBridgeCopyDataLastTick, NativeDropBridgeSilentMode
    t0 := A_TickCount
    if !EnableNativeDropBridge
        return
    if (NativeDropBridgePID && ProcessExist(NativeDropBridgePID)) {
        NativeDropBridgeSilentMode := false
        SetTimer(NativeDropBridge_Poll, 250)
        SetTimer(NativeDropBridge_Watchdog, 180)
        return
    }
    if (existingPid := ProcessExist("native-drop-bridge.exe")) {
        NativeDropBridgePID := existingPid
        NativeDropBridgeSilentMode := false
        SplitPath(NativeDropBridgeOut, , &outDir)
        if (outDir != "" && !DirExist(outDir))
            DirCreate(outDir)
        if !FileExist(NativeDropBridgeOut)
            FileAppend("", NativeDropBridgeOut, "UTF-8")
        f := FileOpen(NativeDropBridgeOut, "r")
        if f {
            NativeDropBridgeReadOffset := f.Length
            f.Close()
        } else {
            NativeDropBridgeReadOffset := 0
        }
        NativeDropBridgeStartTick := A_TickCount
        NativeDropBridgeCopyDataLastTick := 0
        SetTimer(NativeDropBridge_Poll, 250)
        SetTimer(NativeDropBridge_Watchdog, 180)
        NMER_Log("activation", "native_drop_bridge_reused", "pid=" . existingPid . " elapsed_ms=" . (A_TickCount - t0))
        return
    }
    if !FileExist(NativeDropBridgeExe)
        return
    try {
        SplitPath(NativeDropBridgeOut, , &outDir)
        if (outDir != "" && !DirExist(outDir))
            DirCreate(outDir)
        if !FileExist(NativeDropBridgeOut)
            FileAppend("", NativeDropBridgeOut, "UTF-8")
        f := FileOpen(NativeDropBridgeOut, "r")
        if f {
            NativeDropBridgeReadOffset := f.Length
            f.Close()
        } else {
            NativeDropBridgeReadOffset := 0
        }
        rect := NativeDropBridge_GetDropRect()
        rx := Integer(rect["x"]), ry := Integer(rect["y"]), rw := Integer(rect["w"]), rh := Integer(rect["h"])
        cmd := '"' . NativeDropBridgeExe . '" --out "' . NativeDropBridgeOut . '" --x ' . rx . ' --y ' . ry . ' --w ' . rw . ' --h ' . rh
        cmd .= ' --ws 127.0.0.1:18790 --gate-follow'
        if (NativeDropBridgeUseCopyData && NativeDropBridgeCopyDataReady)
            cmd .= ' --copydata --ahk-class "AutoHotkey" --ahk-title "' . NativeDropBridgeCopyDataTitle . '"'
        Run(cmd, A_ScriptDir, "Hide", &pid)
        NativeDropBridgePID := pid
        NativeDropBridgeSilentMode := false
        NativeDropBridgeStartTick := A_TickCount
        NativeDropBridgeCopyDataLastTick := 0
        SetTimer(NativeDropBridge_Poll, 250)
        SetTimer(NativeDropBridge_Watchdog, 180)
        NMER_Log("activation", "native_drop_bridge_started", "pid=" . pid . " elapsed_ms=" . (A_TickCount - t0))
    } catch {
    }
}

NativeDropBridge_GetDropRect() {
    global NativeDropBridgeFullScreenHitTest
    global GDHO_GUI, GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y, GDHO_HOST_W, GDHO_HOST_H
    if (NativeDropBridgeFullScreenHitTest) {
        left := SysGet(76), top := SysGet(77), vw := SysGet(78), vh := SysGet(79)
        return Map("x", Integer(left), "y", Integer(top), "w", Integer(vw), "h", Integer(vh))
    }
    if (FuncExists("GDHO_IsHoleOnlyMode") && GDHO_IsHoleOnlyMode()) {
        hx := Integer(GDHO_LAST_HOST_X), hy := Integer(GDHO_LAST_HOST_Y)
        hw := Integer(GDHO_HOST_W), hh := Integer(GDHO_HOST_H)
        if (GDHO_GUI && GDHO_GUI.Hwnd) {
            try {
                GDHO_GUI.GetPos(&hx, &hy, &hw, &hh)
            } catch {
            }
        }
        if (hw > 0 && hh > 0)
            return Map("x", hx, "y", hy, "w", hw, "h", hh)
    }
    ; Keep receiver roughly aligned to hole visual area near toolbar.
    x := 300, y := 300, w := 170, h := 210
    try {
        global FloatingToolbarGUI
        if (FloatingToolbarGUI && FloatingToolbarGUI.Hwnd) {
            FloatingToolbarGUI.GetPos(&tx, &ty, &tw, &th)
            x := Integer(tx + Max(0, Round((tw - w) / 2)))
            y := Integer(ty - h - 12)
            if (y < 12)
                y := Integer(ty + th + 12)
        }
    } catch {
    }
    return Map("x", x, "y", y, "w", w, "h", h)
}

NativeDropBridge_Stop() {
    global NativeDropBridgePID, NativeDropBridgeCopyDataLastTick, NativeDropBridgeStartTick, NativeDropBridgeSilentMode
    t0 := A_TickCount
    try SetTimer(NativeDropBridge_Poll, 0)
    try SetTimer(NativeDropBridge_Watchdog, 0)
    if (NativeDropBridgePID && ProcessExist(NativeDropBridgePID)) {
        try ProcessClose(NativeDropBridgePID)
    }
    NativeDropBridgePID := 0
    NativeDropBridgeCopyDataLastTick := 0
    NativeDropBridgeStartTick := 0
    NativeDropBridgeSilentMode := false
    NMER_Log("activation", "native_drop_bridge_stopped", "elapsed_ms=" . (A_TickCount - t0))
}

NativeDropBridge_InitCopyDataReceiver() {
    global NativeDropBridgeUseCopyData, NativeDropBridgeCopyDataTitle, NativeDropBridgeCopyDataGui, NativeDropBridgeCopyDataReady
    if !NativeDropBridgeUseCopyData {
        NativeDropBridgeCopyDataReady := false
        return
    }
    try {
        if !IsObject(NativeDropBridgeCopyDataGui) {
            NativeDropBridgeCopyDataGui := Gui("+ToolWindow -Caption", NativeDropBridgeCopyDataTitle)
            NativeDropBridgeCopyDataGui.Show("Hide")
        }
        OnMessage(0x4A, NativeDropBridge_OnCopyData)
        NativeDropBridgeCopyDataReady := true
    } catch {
        NativeDropBridgeCopyDataReady := false
    }
}

NativeDropBridge_OnCopyData(wParam, lParam, msg, hwnd) {
    global NativeDropBridgeCopyDataGui, NativeDropBridgeLastEvent, NativeDropLastEventTick, NativeDropBridgeCopyDataLastTick, NativeDropBridgeSilentMode
    if NativeDropBridgeSilentMode
        return 1
    try {
        if !IsObject(NativeDropBridgeCopyDataGui)
            return 0
        if (hwnd != NativeDropBridgeCopyDataGui.Hwnd)
            return 0
        cbData := NumGet(lParam + A_PtrSize, "UInt")
        lpData := NumGet(lParam + A_PtrSize + 4, "Ptr")
        if (cbData <= 0 || lpData = 0)
            return 1
        line := StrGet(lpData, cbData, "UTF-8")
        line := Trim(StrReplace(line, Chr(0), ""), "`r`n`t ")
        if (line = "")
            return 1
        evt := Jxon_Load(line)
        NativeDropBridgeCopyDataLastTick := A_TickCount
        NativeDropBridgeLastEvent := evt
        NativeDropLastEventTick := A_TickCount
        try NativeDropDiag_Log("evt(copydata) " . line)
        try {
            k := ""
            try k := String(evt["kind"])
            GDHO_RunJS("window.HoleOverlay?.setNativeState({ kind: '" . k . "', dispatch: 'evt' })")
        }
        NativeDropBridge_TriggerHolePulse(evt)
        return 1
    } catch {
        return 0
    }
}

NativeDropBridge_Poll(*) {
    global NativeDropBridgeOut, NativeDropBridgeReadOffset, NativeDropBridgeLastEvent, NativeDropLastEventTick
    global NativeDropBridgeUseCopyData, NativeDropBridgeCopyDataReady, NativeDropBridgeCopyDataLastTick, NativeDropBridgeStartTick, NativeDropBridgeCopyDataFallbackMs
    global g_HoleRuntimeEnabled, NativeDropBridgeSilentMode
    if (!g_HoleRuntimeEnabled || NativeDropBridgeSilentMode)
        return
    if (NativeDropBridgeUseCopyData && NativeDropBridgeCopyDataReady) {
        nowTick := A_TickCount
        if (NativeDropBridgeCopyDataLastTick > 0 && (nowTick - NativeDropBridgeCopyDataLastTick) <= NativeDropBridgeCopyDataFallbackMs)
            return
        if (NativeDropBridgeCopyDataLastTick = 0 && NativeDropBridgeStartTick > 0 && (nowTick - NativeDropBridgeStartTick) <= NativeDropBridgeCopyDataFallbackMs)
            return
    }
    try {
        if !FileExist(NativeDropBridgeOut)
            return
        f := FileOpen(NativeDropBridgeOut, "r")
        if !f
            return
        if (NativeDropBridgeReadOffset > f.Length)
            NativeDropBridgeReadOffset := 0
        f.Pos := NativeDropBridgeReadOffset
        while !f.AtEOF {
            line := Trim(f.ReadLine(), "`r`n`t ")
            if (line = "")
                continue
            try {
                evt := Jxon_Load(line)
                NativeDropBridgeLastEvent := evt
                NativeDropLastEventTick := A_TickCount
                try NativeDropDiag_Log("evt " . line)
                try {
                    k := ""
                    try k := String(evt["kind"])
                    GDHO_RunJS("window.HoleOverlay?.setNativeState({ kind: '" . k . "', dispatch: 'evt' })")
                }
                NativeDropBridge_TriggerHolePulse(evt)
            } catch {
            }
        }
        NativeDropBridgeReadOffset := f.Pos
        f.Close()
    } catch {
    }
}

NativeDropBridge_TriggerHolePulse(evt) {
    global EnableHoleOverlayOnNativeDrop, NativeDropSessionActive, NativeDropHideDelayMs, NativeDropSessionPayload, NativeDropOverHole, NativeDropWasOverHole, NativeDropWeakPreviewShown, NativeDropSawOutsideHole, NativeDropValidEnterHole, NativeDropMovedEnough, NativeDropCurrentMoveDistance, NativeDropMinCommitDistancePx, NativeDropMinCommitMs, NativeDropEnterHoleTick, NativeDropMinDwellInHoleMs, NativeDropSeedText
    global NativeDropLastStartTick, NativeDropRearmUntil
    global NativeDropAwaitingDragEnd, NativeDropAwaitingDragEndSince
    global GDHO_STATE, GDHO_HOVER_VALID, GDHO_DWELL_START_TICK, GDHO_LAST_PROXIMITY
    global GDHO_SIZE_SCALE, GDHO_ANIM_LEVEL, GDHO_VISUAL_STYLE, GDHO_DRAG_CONFIDENCE
    global g_HoleRuntimeEnabled, NativeDropBridgeSilentMode
    if (!g_HoleRuntimeEnabled || NativeDropBridgeSilentMode)
        return
    if !EnableHoleOverlayOnNativeDrop
        return
    if !IsObject(evt)
        return
    kindRaw := ""
    try kindRaw := StrLower(Trim(String(evt["kind"])))
    catch {
        return
    }
    payloadRaw := ""
    try payloadRaw := StrLower(Trim(String(evt["payloadKind"])))
    catch {
        payloadRaw := ""
    }
    kindMapped := NativeDropBridge_NormalizeHolePayloadKind(payloadRaw)
    try GDHO_RunJS("window.HoleOverlay?.setNativeState({ kind: '" . kindRaw . "', dispatch: 'route', active: " . (NativeDropSessionActive ? "1" : "0") . ", overHole: " . (NativeDropOverHole ? "1" : "0") . ", wasOverHole: " . (NativeDropWasOverHole ? "1" : "0") . ", payload: '" . NativeDropSessionPayload . "' })")
    fallbackPayload := ""
    resolveDetail := ""
    if (kindRaw = "drag_start" || kindRaw = "drag_enter") {
        nowTick := A_TickCount
        ; Rearm gate: after closing SearchCenter/reset, ignore a few stale bridge ticks.
        if (NativeDropRearmUntil > 0 && nowTick < NativeDropRearmUntil) {
            try NativeDropDiag_Log("route kind=" . kindRaw . " action=ignore reason=rearm_gate remain_ms=" . (NativeDropRearmUntil - nowTick))
            return
        }
        ; Start debounce: suppress duplicate drag_start/drag_enter bursts.
        if (NativeDropLastStartTick > 0 && (nowTick - NativeDropLastStartTick) < 90) {
            try NativeDropDiag_Log("route kind=" . kindRaw . " action=ignore reason=start_debounce delta_ms=" . (nowTick - NativeDropLastStartTick))
            return
        }
        NativeDropLastStartTick := nowTick
        guessX := "", guessY := ""
        try guessX := Integer(evt["x"])
        try guessY := Integer(evt["y"])
        if (kindMapped = "")
            kindMapped := NativeDropBridge_GuessPayloadForUnknownDrag(&fallbackPayload, guessX, guessY)
        if (kindMapped = "")
            kindMapped := NativeDropBridge_ResolveStartKind(evt, &resolveDetail)
        if (IsSet(resolveDetail) && resolveDetail != "")
            fallbackPayload := (fallbackPayload != "" ? fallbackPayload . ";" : "") . resolveDetail
        if NativeDropBridge_ShouldIgnoreDragEvent(kindRaw, payloadRaw, kindMapped) {
            NativeDropSessionActive := false
            try SetTimer(NativeDropBridge_DragSessionTick, 0)
            return
        }
        if (kindMapped = "")
            kindMapped := "text"
        if (kindMapped = "text" && FuncExists("SelectionSense_ShouldBlockBridgeTextDrag") && SelectionSense_ShouldBlockBridgeTextDrag()) {
            try NativeDropDiag_Log("route kind=" . kindRaw . " action=ignore_text reason=not_dragging_phase")
            return
        }
        ; Init session only once (usually on drag_start). Repeated drag_enter should not
        ; reset movement gate, otherwise weak preview may never show.
        isFreshSession := !NativeDropSessionActive
        if isFreshSession {
            if FuncExists("NativeDropBridge_BumpSessionId")
                NativeDropBridge_BumpSessionId()
            if FuncExists("NativeDropCursorSync_Start")
                NativeDropCursorSync_Start()
            NativeDropSessionActive := true
            NativeDropAwaitingDragEnd := false
            NativeDropAwaitingDragEndSince := 0
            GDHO_STATE := "ARMED"
            GDHO_HOVER_VALID := false
            GDHO_DWELL_START_TICK := 0
            GDHO_LAST_PROXIMITY := 0.0
            NativeDropSessionPayload := kindMapped
            NativeDropOverHole := false
            NativeDropWasOverHole := false
            NativeDropWeakPreviewShown := false
            NativeDropSawOutsideHole := false
            NativeDropValidEnterHole := false
            NativeDropMovedEnough := false
            NativeDropCurrentMoveDistance := 0.0
            NativeDropEnterHoleTick := 0
            sx := ""
            sy := ""
            try sx := Integer(evt["x"])
            try sy := Integer(evt["y"])
            if (sx != "" && sy != "") {
                NativeDropStartMouseX := sx
                NativeDropStartMouseY := sy
            } else {
                CoordMode("Mouse", "Screen")
                MouseGetPos(&smx, &smy)
                NativeDropStartMouseX := smx
                NativeDropStartMouseY := smy
            }
        } else {
            NativeDropSessionPayload := kindMapped
        }
        if (kindMapped = "text") {
            ; Some apps report text-drag starts with transient/false LButton state.
            ; Keep routing when selection state indicates text is already captured.
            if !GetKeyState("LButton", "P") {
                allowBySelectionState := false
                try {
                    if FuncExists("SelectionSense_IsTextCapturedForHole")
                        allowBySelectionState := !!SelectionSense_IsTextCapturedForHole()
                } catch {
                    allowBySelectionState := false
                }
                if !allowBySelectionState {
                    try NativeDropDiag_Log("route kind=" . kindRaw . " action=ignore_text reason=lbutton_up")
                    return
                }
                try NativeDropDiag_Log("route kind=" . kindRaw . " action=allow_text reason=lbutton_up_selection_state")
            }
            srcHwnd := 0
            try {
                if (evt.Has("x") && evt.Has("y") && FuncExists("GDHO_HwndFromScreenPoint"))
                    srcHwnd := GDHO_HwndFromScreenPoint(Integer(evt["x"]), Integer(evt["y"]))
            } catch {
            }
            if FuncExists("GDHO_CaptureTextSeedAtDragStart") {
                try NativeDropSeedText := GDHO_CaptureTextSeedAtDragStart(srcHwnd)
            } else {
                NativeDropSeedText := NativeDropBridge_CaptureTextSeed()
            }
            if FuncExists("NativeDropBridge_SetReceiverVisible")
                try NativeDropBridge_SetReceiverVisible(false)
        } else {
            NativeDropSeedText := ""
            if FuncExists("NativeDropBridge_SetReceiverVisible")
                try NativeDropBridge_SetReceiverVisible(true)
        }
        try SetTimer(NativeDropBridge_DelayedHide, 0) ; cancel pending hide
        try SetTimer(NativeDropBridge_DragSessionTick, 60)
        if (kindMapped = "file")
            NativeDropBridge_ActivateFileDragHole(evt)
        ; Restore event-driven preview on drag_start/drag_enter (legacy-stable behavior):
        ; users should see starry hole activate immediately when text/file drag begins.
        actionTag := isFreshSession ? "arm_show_preview" : "arm_keep_session"
        try NativeDropDiag_Log("route kind=" . kindRaw . " action=" . actionTag . " payload=" . payloadRaw . " mapped=" . kindMapped . (fallbackPayload != "" ? " fallback=" . fallbackPayload : ""))
        try GDHO_RunJS("window.HoleOverlay?.setNativeState({ kind: '" . kindRaw . "', dispatch: '" . actionTag . ":" . kindMapped . "', active: 1, overHole: 0, wasOverHole: " . (NativeDropWasOverHole ? "1" : "0") . ", payload: '" . kindMapped . "' })")
        if isFreshSession {
            try {
                GDHO_Init()
                GDHO_Show(kindMapped)
                ; WebView readiness can be delayed for the first tick; retry quickly.
                SetTimer((*) => (NativeDropSessionActive ? GDHO_Show(NativeDropSessionPayload) : 0), -120)
                SetTimer((*) => (NativeDropSessionActive ? GDHO_Show(NativeDropSessionPayload) : 0), -320)
                SetTimer((*) => (NativeDropSessionActive ? GDHO_Show(NativeDropSessionPayload) : 0), -620)
            } catch {
            }
        }
        try HoleDragHooks_Emit("activate", Map(
            "kind", kindRaw,
            "payload", kindMapped,
            "active", true,
            "overHole", false,
            "wasOverHole", !!NativeDropWasOverHole,
            "x", evt.Has("x") ? Integer(evt["x"]) : 0,
            "y", evt.Has("y") ? Integer(evt["y"]) : 0,
            "ts", A_TickCount
        ))
        return
    }
    if (kindRaw = "drag_end") {
        canCommit := false
        try {
            endX := ""
            endY := ""
            strictOverHole := false
            try endX := Integer(evt["x"])
            try endY := Integer(evt["y"])
            if (endX != "" && endY != "") {
                dxEnd := Integer(endX) - Integer(NativeDropStartMouseX)
                dyEnd := Integer(endY) - Integer(NativeDropStartMouseY)
                NativeDropCurrentMoveDistance := Max(NativeDropCurrentMoveDistance, Sqrt(dxEnd * dxEnd + dyEnd * dyEnd))
                NativeDropOverHole := GDHO_IsPointInHole(endX, endY, 30)
                ; Commit must land in a tighter core zone, not the wide hover assist zone.
                strictOverHole := GDHO_IsPointInHole(endX, endY, -26)
            } else {
                strictOverHole := false
            }
            try NativeDropDiag_Log("route drag_end over_hole=" . (NativeDropOverHole ? "1" : "0") . " payload=" . NativeDropSessionPayload)
            try GDHO_RunJS("window.HoleOverlay?.setNativeState({ kind: 'drag_end', dispatch: 'over_hole=" . (NativeDropOverHole ? "1" : "0") . "', active: 1, overHole: " . (NativeDropOverHole ? "1" : "0") . ", wasOverHole: " . (NativeDropWasOverHole ? "1" : "0") . ", payload: '" . NativeDropSessionPayload . "' })")
            sinceStartMs := (NativeDropLastStartTick > 0) ? (A_TickCount - NativeDropLastStartTick) : 9999
            dwellMs := (NativeDropEnterHoleTick > 0) ? (A_TickCount - NativeDropEnterHoleTick) : 0
            canCommit := NativeDropMovedEnough
                && GDHO_HOVER_VALID
                && NativeDropOverHole
                && strictOverHole
                && NativeDropWasOverHole
                && NativeDropValidEnterHole
                && (NativeDropCurrentMoveDistance >= NativeDropMinCommitDistancePx)
                && (sinceStartMs >= NativeDropMinCommitMs)
                && (dwellMs >= NativeDropMinDwellInHoleMs)
            if (NativeDropSessionPayload = "text" && !canCommit) {
                try NativeDropDiag_Log("route drag_end_text action=blocked dist=" . Round(NativeDropCurrentMoveDistance, 1) . " min_dist=" . NativeDropMinCommitDistancePx . " ms=" . sinceStartMs . " min_ms=" . NativeDropMinCommitMs . " hover_valid=" . (GDHO_HOVER_VALID ? "1" : "0") . " over_hole=" . (NativeDropOverHole ? "1" : "0") . " strict_over_hole=" . (strictOverHole ? "1" : "0") . " dwell_ms=" . dwellMs . " min_dwell=" . NativeDropMinDwellInHoleMs)
                if (NativeDropOverHole || (endX != "" && endY != "" && FuncExists("GDHO_ShouldTextSuckAtPoint") && GDHO_ShouldTextSuckAtPoint(Integer(endX), Integer(endY)))) {
                    try GDHO_SubmitReleaseSignal("physical", Map("mx", (endX != "" ? Integer(endX) : NativeDropLastTickMouseX), "my", (endY != "" ? Integer(endY) : NativeDropLastTickMouseY), "inSuckZone", true))
                }
            }
            if (NativeDropSessionPayload = "file") {
                fileCommit := NativeDropOverHole && strictOverHole
                    && (NativeDropCurrentMoveDistance >= NativeDropMinCommitDistancePx)
                try NativeDropDiag_Log("route drag_end_file action=" . (fileCommit ? "commit" : "cancel") . " over_hole=" . (NativeDropOverHole ? "1" : "0"))
                try HoleDragHooks_Emit("release", Map(
                    "kind", "drag_end",
                    "payload", NativeDropSessionPayload,
                    "commit", !!fileCommit,
                    "overHole", !!NativeDropOverHole,
                    "strictOverHole", !!strictOverHole,
                    "wasOverHole", !!NativeDropWasOverHole,
                    "hoverValid", !!GDHO_HOVER_VALID,
                    "x", (endX != "" ? Integer(endX) : 0),
                    "y", (endY != "" ? Integer(endY) : 0),
                    "distance", Round(NativeDropCurrentMoveDistance, 1),
                    "ts", A_TickCount
                ))
                if fileCommit {
                    try {
                        GDHO_ForceSuckAction()
                        SetTimer(GDHO_FinishSuckSession, -2000)
                    } catch {
                    }
                }
                try NativeDropBridge_ResetSessionAsync("drag_end_file", 300)
                return
            }
        } catch {
        }
        try GDHO_SubmitReleaseSignal("bridge_drag_end", Map("canCommit", canCommit, "payload", NativeDropSessionPayload))
        try HoleDragHooks_Emit("release", Map(
            "kind", "drag_end",
            "payload", NativeDropSessionPayload,
            "commit", !!canCommit,
            "overHole", !!NativeDropOverHole,
            "wasOverHole", !!NativeDropWasOverHole,
            "hoverValid", !!GDHO_HOVER_VALID,
            "distance", Round(NativeDropCurrentMoveDistance, 1),
            "ts", A_TickCount
        ))
        return
    }

    if (kindRaw = "drop") {
        kind := kindMapped
        if (kind = "")
            kind := NativeDropBridge_GuessPayloadForUnknownDrag(&fallbackPayload)
        if (kind = "") {
            try NativeDropDiag_Log("route kind=drop action=ignore payload=" . payloadRaw)
            return
        }
        if (kind = "text") {
            try NativeDropDiag_Log("route kind=drop action=coalesce_text")
            clone := Map()
            for kk, vv in evt
                clone[kk] := vv
            try GDHO_SubmitReleaseSignal("bridge_drop", clone)
            return
        }
        NativeDropSessionPayload := kind
        try NativeDropDiag_Log("route kind=drop payload=" . payloadRaw . " mapped=" . kind . (fallbackPayload != "" ? " fallback=" . fallbackPayload : ""))
        try GDHO_RunJS("window.HoleOverlay?.setNativeState({ kind: 'drop', dispatch: 'mapped:" . kind . "', active: 1, overHole: " . (NativeDropOverHole ? "1" : "0") . ", wasOverHole: " . (NativeDropWasOverHole ? "1" : "0") . ", payload: '" . kind . "' })")
        try HoleDragHooks_Emit("release", Map(
            "kind", "drop",
            "payload", kind,
            "commit", true,
            "overHole", !!NativeDropOverHole,
            "wasOverHole", !!NativeDropWasOverHole,
            "ts", A_TickCount
        ))
        try {
            SetTimer(NativeDropBridge_DelayedHide, 0)
            SetTimer(NativeDropBridge_DragSessionTick, 0)
            GDHO_Init()
            GDHO_Show(kind)
            GDHO_Drop(kind)
            SetTimer((*) => GDHO_HideFrontend(), -900)
            SetTimer((*) => GDHO_HideOverlay(), -1200)
        } catch {
        }
        try NativeDropBridge_ApplyDropAction(evt, kind)
        NativeDropBridge_ResetSessionAsync("drop", 300)
        return
    }

    ; Backward compatibility for older bridge payload.
    if (kindRaw != "text" && kindRaw != "file" && kindRaw != "folder" && kindRaw != "link" && kindRaw != "mixed")
        return
    kind := NativeDropBridge_NormalizeHolePayloadKind(kindRaw)
    if (kind = "text") {
        try NativeDropDiag_Log("route legacy kind=" . kindRaw . " action=ignore_text reason=strict_drag_end_commit")
        return
    }
    try NativeDropDiag_Log("route legacy kind=" . kindRaw . " mapped=" . kind)
    try {
        GDHO_Init()
        GDHO_Show(kind)
        SetTimer((*) => GDHO_Drop(kind), -120)
        SetTimer((*) => GDHO_HideFrontend(), -920)
        SetTimer((*) => GDHO_HideOverlay(), -1200)
    } catch {
    }
    try NativeDropBridge_ApplyDropAction(evt, kind)
}

NativeDropBridge_ApplyDropAction(evt, kind := "") {
    global NativeDropSeedText
    kind0 := StrLower(Trim(String(kind)))
    if (kind0 = "")
        kind0 := "text"

    if (kind0 = "text") {
        t := ""
        try t := Trim(String(NativeDropSeedText))
        if (t = "")
            try t := Trim(String(NativeDropBridge_CaptureTextSeed()))
        if (t != "") {
            try GDHO_RunJS("window.HoleOverlay?.setNativeState({ dispatch: 'text_drag_commit' })")
            GDHO_RoutePayload("text", t)
        } else {
            try GDHO_RunJS("window.HoleOverlay?.setNativeState({ dispatch: 'text_drag_overlay_only' })")
        }
        return true
    }

    files := []
    sourceFmt := ""
    itemCount := 0
    try sourceFmt := StrLower(Trim(String(evt["sourceFormat"])))
    try itemCount := Integer(evt["count"])
    if (IsObject(evt) && evt.Has("files") && (evt["files"] is Array)) {
        for _, p in evt["files"] {
            s := Trim(String(p))
            if (s != "")
                files.Push(s)
        }
    }
    if (IsObject(evt) && evt.Has("folders") && (evt["folders"] is Array)) {
        for _, p in evt["folders"] {
            s := Trim(String(p))
            if (s != "")
                files.Push(s)
        }
    }
    if (files.Length > 0) {
        ; Outlook style virtual attachments provide display names (FileGroupDescriptorW), not real filesystem paths.
        ; Route these names to search flow instead of file-path pipeline.
        if (sourceFmt = "filegroupdescriptorw") {
            names := ""
            sep := ""
            for _, p in files {
                names .= sep . p
                sep := Chr(32) . Chr(59) . Chr(32)
            }
            try GDHO_RunJS("window.HoleOverlay?.setNativeState({ dispatch: 'outlook_attachments:" . files.Length . "' })")
            try FloatingToolbar_ActivateSearchCenter()
            if (names != "")
                try FloatingToolbar_RequestSearchByKeyword(names)
            return true
        }
        try GDHO_RunJS("window.HoleOverlay?.setNativeState({ dispatch: 'files:" . files.Length . "' })")
        if (itemCount > 0)
            try NativeDropDiag_Log("drop action files count=" . itemCount . " source=" . sourceFmt)
        if FuncExists("GDHO_RoutePayload") {
            try GDHO_RoutePayload("file", files)
            return true
        }
        if FuncExists("HoleWhisper_TryRouteAudioFiles") && HoleWhisper_TryRouteAudioFiles(files)
            return true
        try return FloatingToolbar_HandleDroppedFiles(files)
    }
    try GDHO_RunJS("window.HoleOverlay?.setNativeState({ dispatch: 'files:empty' })")
    return false
}

NativeDropBridge_ShouldIgnoreDragEvent(kindRaw, payloadRaw, kindMapped := "") {
    global FloatingToolbarDragging
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my, &hwnd)
    if (IsSet(FloatingToolbarDragging) && FloatingToolbarDragging) {
        try NativeDropDiag_Log("route kind=" . kindRaw . " action=ignore reason=toolbar_dragging")
        return true
    }
    if (kindMapped = "file" && FuncExists("GDHO_IsHoleOnlyMode") && GDHO_IsHoleOnlyMode()) {
        try NativeDropDiag_Log("route kind=" . kindRaw . " action=allow_file_hole_mode")
        return false
    }
    if (kindMapped = "file") {
        ; File drags (including mp3) should always be allowed to arm hole workflow.
        try NativeDropDiag_Log("route kind=" . kindRaw . " action=allow_file")
        return false
    }
    if (GDHO_IsOwnWindowHwnd(hwnd) || GDHO_IsOwnProcessHwnd(hwnd)) {
        try NativeDropDiag_Log("route kind=" . kindRaw . " action=ignore reason=own_ui_or_process")
        return true
    }
    if (kindMapped != "text" && GDHO_IsPointInToolbar(mx, my) && !(FuncExists("GDHO_IsHoleOnlyMode") && GDHO_IsHoleOnlyMode())) {
        try NativeDropDiag_Log("route kind=" . kindRaw . " action=ignore reason=cursor_in_toolbar")
        return true
    }
    ; payloadKind from bridge drag_start is often "none". Do not hard-ignore:
    ; let caller fall back to guessed/default route to keep hole responsive.
    if (kindMapped = "") {
        try NativeDropDiag_Log("route kind=" . kindRaw . " action=allow_unknown payload=" . payloadRaw)
        return false
    }
    return false
}

NativeDropBridge_ResolveStartKind(evt := 0, &detail := "") {
    detail := ""
    payloadRaw := ""
    try payloadRaw := StrLower(Trim(String(evt["payloadKind"])))
    kind := NativeDropBridge_NormalizeHolePayloadKind(payloadRaw)
    if (kind != "") {
        detail := "payload=" . payloadRaw
        return kind
    }
    ; payloadKind may be "none" on drag_start: infer file intent from source metadata.
    srcFmt := ""
    try srcFmt := StrLower(Trim(String(evt["sourceFormat"])))
    if (srcFmt != "") {
        if (InStr(srcFmt, "hdrop") || InStr(srcFmt, "filegroupdescriptor")
            || InStr(srcFmt, "shell idlist") || InStr(srcFmt, "shellidlist")
            || InStr(srcFmt, "filename")) {
            detail := "source=" . srcFmt
            return "file"
        }
    }
    if (IsObject(evt) && evt.Has("files") && (evt["files"] is Array) && evt["files"].Length > 0) {
        detail := (detail != "" ? detail . ";" : "") . "evt.files>0"
        return "file"
    }
    if (IsObject(evt) && evt.Has("folders") && (evt["folders"] is Array) && evt["folders"].Length > 0) {
        detail := (detail != "" ? detail . ";" : "") . "evt.folders>0"
        return "file"
    }
    guessX := "", guessY := ""
    try guessX := Integer(evt["x"])
    try guessY := Integer(evt["y"])
    g := NativeDropBridge_GuessPayloadForUnknownDrag(&detail, guessX, guessY)
    if (g != "")
        return g
    CoordMode("Mouse", "Screen")
    MouseGetPos(, , &hwnd)
    srcClass := GDHO_GetClassByHwnd(hwnd)
    detail := (detail != "" ? detail . ";" : "") . "mouse_class=" . srcClass
    if FuncExists("GDHO_IsExplorerFileDragSource") && GDHO_IsExplorerFileDragSource(srcClass)
        return "file"
    if (srcClass = "Chrome_WidgetWin_1" || srcClass = "Edit" || srcClass = "MozillaWindowClass"
        || srcClass = "Notepad" || srcClass = "RichEditD2DPT" || srcClass = "Chrome_RenderWidgetHostHWND")
        return "text"
    return "text"
}

NativeDropBridge_ActivateFileDragHole(evt := 0) {
    global NativeDropSessionPayload, NativeDropWeakPreviewShown, NativeDropMovedEnough, GDHO_ACTIVE, GDHO_PAYLOAD
    global GDHO_POSITION_MODE, GDHO_SIZE_SCALE, GDHO_ANIM_LEVEL, GDHO_VISUAL_STYLE, GDHO_DRAG_SOURCE_CLASS
    NativeDropSessionPayload := "file"
    GDHO_PAYLOAD := "file"
    NativeDropMovedEnough := true
    mx := "", my := ""
    if IsObject(evt) {
        try mx := Integer(evt["x"])
        try my := Integer(evt["y"])
    }
    if (mx = "" || my = "") {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(, , &hwndUnder)
    GDHO_DRAG_SOURCE_CLASS := GDHO_GetClassByHwnd(hwndUnder)
    try {
        GDHO_RequestOpen(Map("reason", "file_drag_start", "payload", "file", "screenX", mx, "screenY", my, "positionMode", GDHO_POSITION_MODE))
        GDHO_ACTIVE := true
        NativeDropSessionActive := true
        try GDHO_ArmPolling()
        if FuncExists("GDHO_ShowForDrag")
            GDHO_ShowForDrag("file", mx, my)
        else
            GDHO_Show("file", mx, my)
        if FuncExists("NativeDropBridge_ResumeFromTextDrag")
            try NativeDropBridge_ResumeFromTextDrag()
        if FuncExists("GDHO_SetFileDropCapture") && GDHO_IsExplorerFileDragSource()
            GDHO_SetFileDropCapture(true)
        GDHO_EnsureDragSessionInteractive()
        try NativeDropBridge_RestartForHoleDropRect()
        GDHO_Update("file", mx, my)
        GDHO_RunJS("window.HoleOverlay?.setStyle({ scale: " GDHO_SIZE_SCALE ", animLevel: " GDHO_ANIM_LEVEL ", visualStyle: '" GDHO_VISUAL_STYLE "' })")
        NativeDropWeakPreviewShown := true
        try NativeDropDiag_Log("route file_drag_start action=show_hole x=" . mx . " y=" . my . " src=" . GDHO_DRAG_SOURCE_CLASS)
    } catch as e {
        try NativeDropDiag_Log("route file_drag_start action=show_failed err=" . e.Message)
    }
}

NativeDropBridge_SetReceiverVisible(visible := true) {
    static s_lastVisible := -1
    want := !!visible
    if (want = s_lastVisible)
        return
    s_lastVisible := want
    hwnd := 0
    try hwnd := WinExist("ahk_class NMER_NativeDropBridge")
    if !hwnd
        try hwnd := WinExist("ahk_class NMERNativeDropBridge")
    catch {
        hwnd := 0
    }
    if !hwnd
        return
    try {
        if want {
            rect := NativeDropBridge_GetDropRect()
            WinMove(Integer(rect["x"]), Integer(rect["y"]), Integer(rect["w"]), Integer(rect["h"]), "ahk_id " hwnd)
            WinShow("ahk_id " hwnd)
        } else {
            WinMove(-32000, -32000, 1, 1, "ahk_id " hwnd)
            WinHide("ahk_id " hwnd)
        }
        try NativeDropDiag_Log("native_drop_bridge_receiver visible=" . (want ? "1" : "0"))
    } catch {
    }
}

NativeDropBridge_PauseForTextDrag() {
    global g_NativeDropBridgePausedForText, EnableNativeDropBridge
    if !EnableNativeDropBridge
        return
    if g_NativeDropBridgePausedForText
        return
    g_NativeDropBridgePausedForText := true
    try NativeDropBridge_SetReceiverVisible(false)
    try NativeDropDiag_Log("native_drop_bridge_receiver_hidden reason=text_drag")
}

NativeDropBridge_ResumeFromTextDrag() {
    global g_NativeDropBridgePausedForText, EnableNativeDropBridge, g_HoleRuntimeEnabled, NativeDropBridgePID
    if !g_NativeDropBridgePausedForText
        return
    g_NativeDropBridgePausedForText := false
    if (!g_HoleRuntimeEnabled || !EnableNativeDropBridge)
        return
    if !(NativeDropBridgePID && ProcessExist(NativeDropBridgePID))
        try NativeDropBridge_Start()
    try NativeDropBridge_SetReceiverVisible(true)
    try NativeDropDiag_Log("native_drop_bridge_resumed reason=text_drag_end")
}

NativeDropBridge_RestartForHoleDropRect() {
    global EnableNativeDropBridge, NativeDropBridgePID, g_HoleRuntimeEnabled
    if !EnableNativeDropBridge
        return
    if !(g_HoleRuntimeEnabled || (FuncExists("GDHO_IsHoleOnlyMode") && GDHO_IsHoleOnlyMode()))
        return
    try NativeDropDiag_Log("native_drop_bridge_restart hole_rect")
    NativeDropBridge_Stop()
    NativeDropBridge_Start()
}

NativeDropBridge_GuessPayloadForUnknownDrag(&detail := "", x := "", y := "") {
    detail := ""
    hwnd := 0
    if (x != "" && y != "") {
        try hwnd := GDHO_HwndFromScreenPoint(Integer(x), Integer(y))
        catch {
            hwnd := 0
        }
        if hwnd
            detail := "xy=" . Integer(x) . "," . Integer(y)
    }
    if !hwnd {
        CoordMode("Mouse", "Screen")
        MouseGetPos(, , &hwnd)
    }
    srcClass := GDHO_GetClassByHwnd(hwnd)
    ; Explorer/Desktop drags are highly likely file/folder payload.
    if (srcClass = "CabinetWClass" || srcClass = "ExploreWClass" || srcClass = "WorkerW" || srcClass = "Progman") {
        detail := "class=" . srcClass
        return "file"
    }
    ; Browser/edit controls are likely text drags.
    if (srcClass = "Chrome_WidgetWin_1" || srcClass = "Edit" || srcClass = "MozillaWindowClass") {
        detail := "class=" . srcClass
        return "text"
    }
    return ""
}

NativeDropBridge_DelayedHide(*) {
    global NativeDropSessionActive
    if NativeDropSessionActive
        return
    try {
        GDHO_HideFrontend()
        GDHO_HideOverlay()
        NativeDropDiag_Log("route delayed_hide action=hide_now")
    } catch {
    }
}

NativeDropBridge_DragSessionTick(*) {
    global NativeDropSessionActive, NativeDropSessionPayload, NativeDropOverHole, NativeDropWasOverHole, NativeDropSeedText
    global NativeDropLastTickMouseX, NativeDropLastTickMouseY, NativeDropLastStartTick, NativeDropLastEventTick
    global g_HoleRuntimeEnabled, NativeDropBridgeSilentMode, GDHO_VISIBLE, NativeDropWeakPreviewShown, NativeDropSawOutsideHole, NativeDropValidEnterHole
    global NativeDropStartMouseX, NativeDropStartMouseY, NativeDropMovedEnough, NativeDropMoveThresholdPx, NativeDropCurrentMoveDistance
    global NativeDropEnterHoleTick
    global NativeDropAwaitingDragEnd, NativeDropAwaitingDragEndSince
    global GDHO_STATE, GDHO_HOVER_VALID, GDHO_DWELL_START_TICK, GDHO_LAST_PROXIMITY
    global GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y
    global GDHO_SIZE_SCALE, GDHO_ANIM_LEVEL, GDHO_VISUAL_STYLE
    if (!g_HoleRuntimeEnabled || NativeDropBridgeSilentMode)
        return
    if !NativeDropSessionActive
        return
    try {
        GDHO_EnsureDragSessionInteractive()
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
        NativeDropLastEventTick := A_TickCount
        NativeDropLastTickMouseX := mx
        NativeDropLastTickMouseY := my
        dxm := Integer(mx) - Integer(NativeDropStartMouseX)
        dym := Integer(my) - Integer(NativeDropStartMouseY)
        moveDist := Sqrt(dxm * dxm + dym * dym)
        NativeDropCurrentMoveDistance := moveDist
        moveThresh := (NativeDropSessionPayload = "text") ? NativeDropTextMoveThresholdPx : NativeDropMoveThresholdPx
        if (!NativeDropMovedEnough && moveDist >= moveThresh) {
            GDHO_STATE := "TRACKING"
            GDHO_DRAG_CONFIDENCE := 0.9
            NativeDropMovedEnough := true
            try NativeDropDiag_Log("route drag_tick action=move_gate_passed dist=" . Round(moveDist, 1))
            if (!NativeDropWeakPreviewShown && (NativeDropSessionPayload = "text" || NativeDropSessionPayload = "file")) {
                try {
                    if (NativeDropSessionPayload = "file") {
                        if FuncExists("GDHO_ShowForDrag")
                            GDHO_ShowForDrag(NativeDropSessionPayload)
                        else {
                            GDHO_Init()
                            GDHO_Show(NativeDropSessionPayload)
                        }
                        GDHO_EnsureDragSessionInteractive()
                        GDHO_RunJS("window.HoleOverlay?.setStyle({ scale: " GDHO_SIZE_SCALE ", animLevel: " GDHO_ANIM_LEVEL ", visualStyle: '" GDHO_VISUAL_STYLE "' })")
                        try GDHO_RunJS("window.HoleOverlay?.setNativeState({ kind: 'drag_tick', dispatch: 'preview_strong_after_move', active: 1, overHole: 0, wasOverHole: 0, payload: 'file' })")
                    } else {
                        try NativeDropDiag_Log("route drag_tick action=text_select_preview dist=" . Round(moveDist, 1))
                        NativeDropWeakPreviewShown := true
                    }
                    if (NativeDropSessionPayload = "file")
                        NativeDropWeakPreviewShown := true
                } catch {
                }
            }
        }
        if !NativeDropMovedEnough {
            if (NativeDropSessionPayload != "text")
                GDHO_Update(NativeDropSessionPayload, mx, my)
            return
        }
        if (NativeDropSessionPayload = "text" && FuncExists("GDHO_ManageTextDragOverlay")) {
            try GDHO_ManageTextDragOverlay(mx, my)
            return
        }
        NativeDropOverHole := GDHO_IsPointInHole(mx, my, 30)
        hx := Integer(GDHO_LAST_HOST_X) + 90
        hy := Integer(GDHO_LAST_HOST_Y) + 56 + 103
        dxh := Integer(mx) - hx
        dyh := Integer(my) - hy
        holeDist := Sqrt(dxh * dxh + dyh * dyh)
        GDHO_LAST_PROXIMITY := Max(0.0, Min(1.0, 1.0 - (holeDist / 260.0)))
        skipProx := false
        if FuncExists("GDHO_ShouldBlockStarryReentry") {
            try skipProx := GDHO_ShouldBlockStarryReentry()
            catch {
            }
        }
        if !skipProx {
            try GDHO_SetProximity(GDHO_LAST_PROXIMITY)
            try GDHO_ApplyDropHitTestByProximity(GDHO_LAST_PROXIMITY)
        }
        if !NativeDropOverHole
            NativeDropSawOutsideHole := true
        if (NativeDropOverHole && NativeDropSawOutsideHole) {
            NativeDropValidEnterHole := true
            if (NativeDropEnterHoleTick = 0)
                NativeDropEnterHoleTick := A_TickCount
        } else if !NativeDropOverHole {
            NativeDropEnterHoleTick := 0
        }
        if (NativeDropOverHole && GDHO_LAST_PROXIMITY > 0.90) {
            if (GDHO_DWELL_START_TICK = 0)
                GDHO_DWELL_START_TICK := A_TickCount
            GDHO_HOVER_VALID := ((A_TickCount - GDHO_DWELL_START_TICK) >= NativeDropMinDwellInHoleMs)
        } else {
            GDHO_DWELL_START_TICK := 0
            GDHO_HOVER_VALID := false
        }
        if (NativeDropOverHole && !NativeDropWasOverHole) {
            try NativeDropDiag_Log("route drag_tick action=promote_on_enter payload=" . NativeDropSessionPayload)
            try GDHO_RunJS("window.HoleOverlay?.setNativeState({ kind: 'drag_tick', dispatch: 'promote_on_enter', active: 1, overHole: 1, wasOverHole: " . (NativeDropWasOverHole ? "1" : "0") . ", payload: '" . NativeDropSessionPayload . "' })")
            try {
                if !GDHO_VISIBLE {
                    if FuncExists("GDHO_ShowForDrag")
                        GDHO_ShowForDrag(NativeDropSessionPayload)
                    else {
                        GDHO_Init()
                        GDHO_Show(NativeDropSessionPayload)
                    }
                }
                if (NativeDropSessionPayload = "text") {
                    if FuncExists("GDHO_EnsureTextDragPassthrough")
                        try GDHO_EnsureTextDragPassthrough()
                    if FuncExists("GDHO_RaiseTextDragOverlay")
                        try GDHO_RaiseTextDragOverlay()
                }
                ; Restore normal style when pointer first enters hole area.
                if NativeDropWeakPreviewShown {
                    GDHO_RunJS("window.HoleOverlay?.setStyle({ scale: " GDHO_SIZE_SCALE ", animLevel: " GDHO_ANIM_LEVEL ", visualStyle: '" GDHO_VISUAL_STYLE "' })")
                    NativeDropWeakPreviewShown := false
                }
            } catch {
            }
        }
        if NativeDropOverHole
            NativeDropWasOverHole := true
        try GDHO_RunJS("window.HoleOverlay?.setNativeState({ kind: 'drag_tick', dispatch: '" . (NativeDropOverHole ? "over_hole" : "tracking") . "', state: '" . GDHO_STATE . "', ready: " . (GDHO_HOVER_VALID ? "1" : "0") . ", proximity: " . Round(GDHO_LAST_PROXIMITY, 3) . ", active: 1, overHole: " . (NativeDropOverHole ? "1" : "0") . ", wasOverHole: " . (NativeDropWasOverHole ? "1" : "0") . ", payload: '" . NativeDropSessionPayload . "' })")
        try HoleDragHooks_Emit("position", Map(
            "kind", "drag_tick",
            "payload", NativeDropSessionPayload,
            "active", true,
            "x", Integer(mx),
            "y", Integer(my),
            "overHole", !!NativeDropOverHole,
            "wasOverHole", !!NativeDropWasOverHole,
            "hoverValid", !!GDHO_HOVER_VALID,
            "proximity", Round(GDHO_LAST_PROXIMITY, 3),
            "distance", Round(NativeDropCurrentMoveDistance, 1),
            "ts", A_TickCount
        ))
        GDHO_Update(NativeDropSessionPayload, mx, my)
        ; If OS missed/late drag_end, use release fallback.
        ; Guard the first ~280ms to avoid false release on some text-drag sources.
        lbtnDown := GetKeyState("LButton", "P") || GetKeyState("LButton")
        sinceStartMs := (NativeDropLastStartTick > 0) ? (A_TickCount - NativeDropLastStartTick) : 9999
        if (!lbtnDown && sinceStartMs >= 280) {
            ; Wait for bridge drag_end first to avoid double reset races against WebView2 controller state.
            if !NativeDropAwaitingDragEnd {
                NativeDropAwaitingDragEnd := true
                NativeDropAwaitingDragEndSince := A_TickCount
                try NativeDropDiag_Log("route release_fallback action=wait_drag_end")
                return
            }
            waitedMs := A_TickCount - NativeDropAwaitingDragEndSince
            if (waitedMs < 2200)
                return
            try NativeDropDiag_Log("route release_fallback action=timeout_reset waited_ms=" . waitedMs)
            NativeDropBridge_ResetSessionAsync("release_fallback_timeout", 300)
            return
        }
    } catch {
    }
}

NativeDropBridge_ShowWeakPreviewGate(*) {
    global NativeDropSessionActive, NativeDropSessionPayload, NativeDropWeakPreviewShown
    global GDHO_STATE
    global GDHO_SIZE_SCALE, GDHO_ANIM_LEVEL, GDHO_VISUAL_STYLE
    if !NativeDropSessionActive
        return
    if NativeDropWeakPreviewShown
        return
    try {
        GDHO_Init()
        GDHO_Show(NativeDropSessionPayload)
        GDHO_RunJS("window.HoleOverlay?.setStyle({ scale: " GDHO_SIZE_SCALE ", animLevel: " GDHO_ANIM_LEVEL ", visualStyle: '" GDHO_VISUAL_STYLE "' })")
        GDHO_RunJS("window.HoleOverlay?.update({ payload: '" NativeDropSessionPayload "', proximity: 0.55 })")
        NativeDropWeakPreviewShown := true
        GDHO_STATE := "ARMED"
        SetTimer((*) => (NativeDropSessionActive ? GDHO_Show(NativeDropSessionPayload) : 0), -80)
        try NativeDropDiag_Log("route weak_preview action=show_gate payload=" . NativeDropSessionPayload)
        try GDHO_RunJS("window.HoleOverlay?.setNativeState({ kind: 'weak_preview', dispatch: 'show_gate', active: 1, overHole: 0, wasOverHole: 0, payload: '" . NativeDropSessionPayload . "' })")
    } catch {
    }
}

NativeDropBridge_Watchdog(*) {
    global NativeDropSessionActive, NativeDropLastEventTick, NativeDropLastTickMouseX, NativeDropLastTickMouseY, NativeDropLastStartTick
    global g_HoleRuntimeEnabled, NativeDropBridgeSilentMode
    if (!g_HoleRuntimeEnabled || NativeDropBridgeSilentMode)
        return
    if !NativeDropSessionActive
        return
    now := A_TickCount
    idleMs := (NativeDropLastEventTick > 0) ? (now - NativeDropLastEventTick) : 0
    sinceStartMs := (NativeDropLastStartTick > 0) ? (now - NativeDropLastStartTick) : 9999
    physDown := GetKeyState("LButton", "P")
    logDown := GetKeyState("LButton")
    ; Force cleanup only when session is truly stale.
    ; Some text-drag sources don't expose stable LButton state, so keep a wide grace window.
    if ((idleMs > 5000) || (sinceStartMs > 4200 && !physDown && !logDown)) {
        try NativeDropDiag_Log("route watchdog action=force_reset phys=" . (physDown ? "1" : "0") . " log=" . (logDown ? "1" : "0") . " idle_ms=" . idleMs)
        try GDHO_RunJS("window.HoleOverlay?.setNativeState({ kind: 'watchdog', dispatch: 'force_reset', active: 0, overHole: 0, wasOverHole: 0, payload: '-' })")
        NativeDropBridge_ResetSessionAsync("watchdog", 120)
        return
    }
}

NativeDropBridge_NormalizeHolePayloadKind(kindRaw) {
    k := StrLower(Trim(String(kindRaw)))
    ; Current hole frontend supports file/text. Map richer kinds for now.
    if (k = "text" || k = "link")
        return "text"
    if (k = "file" || k = "folder" || k = "mixed")
        return "file"
    return ""
}

NativeDropBridge_TryOpenSearchCenterFromSelection(preferredText := "") {
    t := Trim(String(preferredText))
    if (t = "")
        t := NativeDropBridge_CaptureTextSeed()
    if (t != "") {
        try GDHO_RunJS("window.HoleOverlay?.setNativeState({ dispatch: 'text:captured' })")
        try NativeDropDiag_Log("route drag_end_text action=text_captured len=" . StrLen(t))
    } else {
        try GDHO_RunJS("window.HoleOverlay?.setNativeState({ dispatch: 'text:empty' })")
        try NativeDropDiag_Log("route drag_end_text action=text_empty")
    }
    return true
}

NativeDropBridge_CaptureTextSeed() {
    t := ""
    try t := Trim(String(SelectionSense_GetLastSelectedText()))
    catch {
        t := ""
    }
    if (t = "") {
        try t := Trim(String(A_Clipboard))
    }
    return t
}

NativeDropBridge_ResetSession(reason := "", hideDelayMs := 300, silentMode := false, hideOverlay := true) {
    global NativeDropSessionActive, NativeDropOverHole, NativeDropWasOverHole, NativeDropWeakPreviewShown, NativeDropSawOutsideHole, NativeDropValidEnterHole, NativeDropStartMouseX, NativeDropStartMouseY, NativeDropMovedEnough, NativeDropCurrentMoveDistance, NativeDropEnterHoleTick, NativeDropSeedText
    global NativeDropLastTickMouseX, NativeDropLastTickMouseY
    global NativeDropSessionPayload, NativeDropLastEventTick, NativeDropLastStartTick, NativeDropRearmUntil, NativeDropBridgeSilentMode
    global NativeDropAwaitingDragEnd, NativeDropAwaitingDragEndSince
    global GDHO_STATE, GDHO_HOVER_VALID, GDHO_DWELL_START_TICK, GDHO_LAST_PROXIMITY, GDHO_TriggerSource
    r0 := StrLower(Trim(String(reason)))
    if (r0 = "drag_end" && GDHO_TriggerSource = "selection_copy") {
        try NativeDropDiag_Log("reset_session_skip reason=drag_end trigger_source=selection_copy")
        return
    }
    if FuncExists("SelectionSense_IsSelectionHolePreviewActive") {
        try {
            if SelectionSense_IsSelectionHolePreviewActive() {
                if (r0 = "release_coalesce" || r0 = "release_coalesce_after_suck" || r0 = "watchdog" || r0 = "drag_release"
                    || r0 = "selection_release" || r0 = "selection_captured" || r0 = "drag_idle_timeout") {
                    try NativeDropDiag_Log("reset_session_skip reason=" . reason . " selection_preview=1 hide=0")
                    NativeDropSessionActive := false
                    return
                }
                hideOverlay := false
            }
        } catch {
        }
    }
    if FuncExists("GDHO_ShouldDeferStarryCloseForTextHole") {
        try {
            if GDHO_ShouldDeferStarryCloseForTextHole(r0) {
                hideOverlay := false
                if (r0 = "release_coalesce" || r0 = "release_coalesce_after_suck" || r0 = "release_fallback_timeout"
                    || r0 = "watchdog" || r0 = "drag_release" || r0 = "drag_idle_timeout"
                    || r0 = "selection_release" || r0 = "selection_captured" || r0 = "hide_overlay"
                    || r0 = "hide_overlay_redirect" || r0 = "finish_suck_fallback" || r0 = "drag_end") {
                    try NativeDropDiag_Log("reset_session_skip reason=" . reason . " text_hole_expand=1")
                    NativeDropSessionActive := false
                    return
                }
            }
        } catch {
        }
    }
    if FuncExists("GDHO_IsTextHoleUserPanelActive") {
        try {
            if GDHO_IsTextHoleUserPanelActive() {
                explicitClose := false
                if FuncExists("GDHO_IsExplicitTextHolePanelCloseReason")
                    try explicitClose := GDHO_IsExplicitTextHolePanelCloseReason(r0)
                if !explicitClose {
                    hideOverlay := false
                    if (r0 = "release_coalesce" || r0 = "release_coalesce_after_suck" || r0 = "release_fallback_timeout"
                        || r0 = "watchdog" || r0 = "drag_release" || r0 = "drag_idle_timeout"
                        || r0 = "selection_release" || r0 = "selection_captured" || r0 = "hide_overlay"
                        || r0 = "hide_overlay_redirect" || r0 = "finish_suck_fallback" || r0 = "drag_end") {
                        try NativeDropDiag_Log("reset_session_skip reason=" . reason . " panel_locked=1")
                        NativeDropSessionActive := false
                        return
                    }
                }
            }
        } catch {
        }
    }
    if FuncExists("GDHO_ShouldKeepTextHolePanel") {
        try {
            if GDHO_ShouldKeepTextHolePanel() {
                if (r0 = "release_coalesce" || r0 = "release_coalesce_after_suck" || r0 = "release_fallback_timeout"
                    || r0 = "watchdog" || r0 = "drag_release" || r0 = "drag_idle_timeout"
                    || r0 = "selection_release" || r0 = "selection_captured") {
                    try NativeDropDiag_Log("reset_session_skip reason=" . reason . " text_hole_panel=1")
                    NativeDropSessionActive := false
                    return
                }
                hideOverlay := false
            }
        } catch {
        }
    }
    global g_SelSense_TextCaptured, g_SelSense_LastFireTick
    if (g_SelSense_TextCaptured && (A_TickCount - Integer(g_SelSense_LastFireTick)) < 8000) {
        if (r0 = "release_coalesce" || r0 = "release_coalesce_after_suck" || r0 = "release_fallback_timeout"
            || r0 = "watchdog" || r0 = "drag_release" || r0 = "drag_idle_timeout"
            || r0 = "selection_release" || r0 = "selection_captured") {
            try NativeDropDiag_Log("reset_session_skip reason=" . reason . " text_captured=1 hide=0")
            NativeDropSessionActive := false
            return
        }
        hideOverlay := false
    }
    if FuncExists("SelectionSense_OnHoleDragSessionEnded") {
        try SelectionSense_OnHoleDragSessionEnded()
        catch {
        }
    }
    specialUiReason := (r0 = "caps_f_search" || r0 = "search_center_exit" || r0 = "hole_close")
    if (NativeDropSessionActive && specialUiReason) {
        try NativeDropDiag_Log("reset_session_skip reason=" . reason . " active_drag=1")
        return
    }
    if (FuncExists("GDHO_IsPostSuckProtected") && GDHO_IsPostSuckProtected()) {
        hideOverlay := false
        try NativeDropDiag_Log("reset_session_post_suck_protect reason=" . reason . " hide=0")
    } else if (r0 = "release_coalesce_after_suck" && FuncExists("GDHO_IsDecoupled") && GDHO_IsDecoupled()) {
        hideOverlay := false
        try NativeDropDiag_Log("reset_session_after_suck_no_hide reason=" . reason)
    }
    try NativeDropDiag_Log("reset_session_begin reason=" . reason . " hide_ms=" . Integer(hideDelayMs))
    if FuncExists("GDHO_SetFileDropCapture") {
        try GDHO_SetFileDropCapture(false)
    }
    if FuncExists("GDHO_RestoreTextDragHostState") {
        try GDHO_RestoreTextDragHostState()
    } else if FuncExists("NativeDropBridge_SetReceiverVisible") {
        try NativeDropBridge_SetReceiverVisible(true)
    }
    NativeDropSessionActive := false
    if FuncExists("NativeDropCursorSync_Stop")
        NativeDropCursorSync_Stop()
    NativeDropSessionPayload := "text"
    NativeDropOverHole := false
    NativeDropWasOverHole := false
    NativeDropWeakPreviewShown := false
    NativeDropSawOutsideHole := false
    NativeDropValidEnterHole := false
    NativeDropStartMouseX := 0
    NativeDropStartMouseY := 0
    NativeDropMovedEnough := false
    NativeDropCurrentMoveDistance := 0.0
    NativeDropEnterHoleTick := 0
    NativeDropAwaitingDragEnd := false
    NativeDropAwaitingDragEndSince := 0
    GDHO_STATE := "IDLE"
    GDHO_HOVER_VALID := false
    GDHO_DWELL_START_TICK := 0
    GDHO_LAST_PROXIMITY := 0.0
    NativeDropSeedText := ""
    GDHO_TriggerSource := ""
    NativeDropLastTickMouseX := 0
    NativeDropLastTickMouseY := 0
    NativeDropLastStartTick := 0
    NativeDropLastEventTick := A_TickCount
    NativeDropRearmUntil := A_TickCount + 120
    try NativeDropDiag_Log("reset_session_step state_cleared reason=" . reason)
    try SetTimer(NativeDropBridge_DragSessionTick, 0)
    try NativeDropDiag_Log("reset_session_step drag_tick_stopped reason=" . reason)
    if (hideDelayMs < 0)
        hideDelayMs := 0
    if (hideOverlay && !specialUiReason) {
        if (hideDelayMs = 0) {
            try NativeDropDiag_Log("reset_session_step hide_frontend_queued reason=" . reason)
            SetTimer((*) => NativeDropBridge_DeferredHideFrontendAndOverlay(reason), -10)
        } else {
            try NativeDropDiag_Log("reset_session_step delayed_hide_begin reason=" . reason . " hide_ms=" . Integer(hideDelayMs))
            try SetTimer(NativeDropBridge_DelayedHide, -Abs(Integer(hideDelayMs)))
            try NativeDropDiag_Log("reset_session_step delayed_hide_done reason=" . reason . " hide_ms=" . Integer(hideDelayMs))
        }
    } else {
        try NativeDropDiag_Log("reset_session_step hide_skipped reason=" . reason)
    }
    ; Ensure overlay window returns to transparent hit-test state after forced cleanup.
    try NativeDropDiag_Log("reset_session_step clickthrough_begin reason=" . reason)
    if (FuncExists("GDHO_IsDecoupled") && GDHO_IsDecoupled()) {
        if FuncExists("GDHO_SetStarryClickThrough")
            try GDHO_SetStarryClickThrough(true, "reset_session_" . reason)
        if FuncExists("GDHO_SetPanelInteractive")
            try GDHO_SetPanelInteractive("reset_session_" . reason)
    } else {
        try GDHO_SetClickThrough(true)
    }
    try NativeDropDiag_Log("reset_session_step clickthrough_done reason=" . reason)
    NativeDropBridgeSilentMode := !!silentMode
    try NativeDropDiag_Log("reset_session_step silent_mode=" . (NativeDropBridgeSilentMode ? "1" : "0") . " reason=" . reason)
    if (!NativeDropBridgeSilentMode && !specialUiReason) {
        try NativeDropDiag_Log("reset_session_step start_bridge_begin reason=" . reason)
        try NativeDropBridge_Start()
        try NativeDropDiag_Log("reset_session_step start_bridge_done reason=" . reason)
    } else if (specialUiReason) {
        try NativeDropDiag_Log("reset_session_step bridge_restart_skipped reason=" . reason)
    }
    try NativeDropDiag_Log("reset_session_step js_begin reason=" . reason)
    if (NativeDropBridgeSilentMode) {
        try GDHO_RunJS("window.HoleOverlay?.setNativeState({ kind: 'reset', dispatch: 'silent_on:" . reason . "', active: 0, overHole: 0, wasOverHole: 0, payload: '-' })")
    } else {
        try GDHO_RunJS("window.HoleOverlay?.setNativeState({ kind: 'reset', dispatch: '" . reason . "', active: 0, overHole: 0, wasOverHole: 0, payload: '-' })")
    }
    try NativeDropDiag_Log("reset_session_step js_done reason=" . reason)
    if (reason != "")
        try NativeDropDiag_Log("route reset_session reason=" . reason . " hide_ms=" . Integer(hideDelayMs))
}

NativeDropBridge_DeferredHideFrontendAndOverlay(reason := "") {
    try NativeDropDiag_Log("reset_session_step hide_frontend_async_begin reason=" . reason)
    try GDHO_HideFrontend()
    catch as err {
        try NativeDropDiag_Log("reset_session_step hide_frontend_async_error reason=" . reason . " msg=" . err.Message)
    }
    try NativeDropDiag_Log("reset_session_step hide_frontend_async_done reason=" . reason)
    try NativeDropDiag_Log("reset_session_step hide_overlay_async_begin reason=" . reason)
    try GDHO_HideOverlay()
    catch as err {
        try NativeDropDiag_Log("reset_session_step hide_overlay_async_error reason=" . reason . " msg=" . err.Message)
    }
    try NativeDropDiag_Log("reset_session_step hide_overlay_async_done reason=" . reason)
}

NativeDropBridge_SetSilentMode(enabled, reason := "") {
    global NativeDropBridgeSilentMode
    NativeDropBridgeSilentMode := !!enabled
    try NativeDropDiag_Log("bridge_silent_mode " . (NativeDropBridgeSilentMode ? "on" : "off") . " reason=" . reason)
}

NativeDropBridge_ResetSessionAsync(reason := "", hideDelayMs := 300, silentMode := false) {
    SetTimer((*) => NativeDropBridge_ResetSessionAsyncRun(reason, hideDelayMs, silentMode), -1)
}

NativeDropBridge_ResetSessionAsyncRun(reason := "", hideDelayMs := 300, silentMode := false) {
    global NativeDropSessionActive, GDHO_TriggerSource
    r := StrLower(Trim(String(reason)))
    if (r = "drag_end" && GDHO_TriggerSource = "selection_copy") {
        try NativeDropDiag_Log("reset_session_async_skip reason=drag_end trigger_source=selection_copy")
        return
    }
    if FuncExists("GDHO_IsLauncherCmdInFlight") {
        try {
            if GDHO_IsLauncherCmdInFlight() && (r = "release_coalesce" || r = "release_coalesce_after_suck" || r = "drag_release"
                || r = "drag_idle_timeout" || r = "hide_overlay" || r = "hide_overlay_redirect" || r = "hole_close"
                || r = "desktop_unpin" || r = "frontend_hole_close") {
                try NativeDropDiag_Log("reset_session_async_skip reason=" . reason . " launcher_cmd_in_flight=1")
                return
            }
        } catch {
        }
    }
    if (FuncExists("GDHO_IsPostSuckProtected") && GDHO_IsPostSuckProtected()) {
        if (r = "release_coalesce_after_suck" || r = "release_coalesce" || r = "drag_idle_timeout" || r = "drag_release"
            || r = "hide_overlay" || r = "hide_overlay_redirect") {
            try NativeDropDiag_Log("reset_session_async_post_suck_protect reason=" . reason)
            try NativeDropBridge_ResetSession(reason, 0, false, false)
            return
        }
    }
    if FuncExists("SelectionSense_IsSelectionHolePreviewActive") {
        try {
            if SelectionSense_IsSelectionHolePreviewActive() && (r = "release_coalesce" || r = "release_coalesce_after_suck" || r = "watchdog"
                || r = "drag_release" || r = "selection_release" || r = "selection_captured" || r = "drag_idle_timeout") {
                try NativeDropDiag_Log("reset_session_async_skip reason=" . reason . " selection_preview=1")
                return
            }
        } catch {
        }
    }
    if FuncExists("GDHO_ShouldDeferStarryCloseForTextHole") {
        try {
            if GDHO_ShouldDeferStarryCloseForTextHole(r) && (r = "release_coalesce" || r = "release_coalesce_after_suck"
                || r = "release_fallback_timeout" || r = "watchdog" || r = "drag_release" || r = "drag_idle_timeout"
                || r = "selection_release" || r = "selection_captured" || r = "hide_overlay"
                || r = "hide_overlay_redirect" || r = "finish_suck_fallback" || r = "drag_end") {
                try NativeDropDiag_Log("reset_session_async_skip reason=" . reason . " text_hole_expand=1")
                return
            }
        } catch {
        }
    }
    if FuncExists("GDHO_IsTextHoleUserPanelActive") {
        try {
            if GDHO_IsTextHoleUserPanelActive() {
                explicitClose := false
                if FuncExists("GDHO_IsExplicitTextHolePanelCloseReason")
                    try explicitClose := GDHO_IsExplicitTextHolePanelCloseReason(r)
                if !explicitClose && (r = "release_coalesce" || r = "release_coalesce_after_suck"
                    || r = "release_fallback_timeout" || r = "watchdog" || r = "drag_release" || r = "drag_idle_timeout"
                    || r = "selection_release" || r = "selection_captured" || r = "hide_overlay"
                    || r = "hide_overlay_redirect" || r = "finish_suck_fallback" || r = "drag_end") {
                    try NativeDropDiag_Log("reset_session_async_skip reason=" . reason . " panel_locked=1")
                    return
                }
            }
        } catch {
        }
    }
    if FuncExists("GDHO_ShouldKeepTextHolePanel") {
        try {
            if (GDHO_ShouldKeepTextHolePanel() && (r = "release_coalesce" || r = "release_coalesce_after_suck"
                || r = "release_fallback_timeout" || r = "watchdog" || r = "drag_release" || r = "drag_idle_timeout"
                || r = "selection_release" || r = "selection_captured")) {
                try NativeDropDiag_Log("reset_session_async_skip reason=" . reason . " text_hole_panel=1")
                return
            }
        } catch {
        }
    }
    global g_SelSense_TextCaptured, g_SelSense_LastFireTick
    if (g_SelSense_TextCaptured && (A_TickCount - Integer(g_SelSense_LastFireTick)) < 8000
        && (r = "release_coalesce" || r = "release_coalesce_after_suck" || r = "release_fallback_timeout"
            || r = "watchdog" || r = "drag_release" || r = "selection_release" || r = "selection_captured"
            || r = "drag_idle_timeout")) {
        try NativeDropDiag_Log("reset_session_async_skip reason=" . reason . " text_captured=1")
        return
    }
    if (NativeDropSessionActive && (r = "caps_f_search" || r = "search_center_exit" || r = "hole_close")) {
        try NativeDropDiag_Log("reset_session_async_skip reason=" . reason . " active_drag=1")
        return
    }
    if (!NativeDropSessionActive && r = "hole_close") {
        try NativeDropDiag_Log("reset_session_async_skip reason=hole_close active_drag=0")
        return
    }
    try NativeDropDiag_Log("reset_session_async_begin reason=" . reason . " hide_ms=" . Integer(hideDelayMs))
    hideOverlay := !(r = "caps_f_search" || r = "search_center_exit" || r = "hole_close" || r = "hole_search_commit")
    if (r = "release_coalesce_after_suck" && FuncExists("GDHO_IsDecoupled") && GDHO_IsDecoupled())
        hideOverlay := false
    if FuncExists("SelectionSense_IsSelectionHolePreviewActive") {
        try {
            if SelectionSense_IsSelectionHolePreviewActive()
                hideOverlay := false
        } catch {
        }
    }
    try NativeDropBridge_ResetSession(reason, hideDelayMs, silentMode, hideOverlay)
    catch as err {
        try NativeDropDiag_Log("reset_session_async_error reason=" . reason . " msg=" . err.Message)
    }
    try NativeDropDiag_Log("reset_session_async_done reason=" . reason . " hide_ms=" . Integer(hideDelayMs))
}

NativeDropDiag_Log(msg) {
    global NativeDropDiagLogPath
    try {
        dir := ""
        SplitPath(NativeDropDiagLogPath, , &dir)
        if (dir != "" && !DirExist(dir))
            DirCreate(dir)
        ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        FileAppend("[" . ts . "] " . String(msg) . "`r`n", NativeDropDiagLogPath, "UTF-8")
    } catch {
    }
}

Global_InitAllPanels(*) {
    global WebViewWarmupStarted

    if WebViewWarmupStarted
        return

    try SurfaceManager_EnsureBootstrap()
    try SurfaceManager_RecordEvent("warmup_start", "", Map("source", "Global_InitAllPanels"))
    WebViewWarmupStarted := true
    WebView2_InitSharedEnvAsync(_WV2_BeginWarmupAfterEnv)
}

StartWebViewWarmup(*) {
    Global_InitAllPanels()
}

#Include modules\ConfigManager.ahk
#Include modules\AppUpdateCheck.ahk
InitConfig() ; 启动初始化
try UserStudio_Load()
try SetTimer(AppUpdateCheck_ScheduleStartup, -8000)
try GDHO_LoadSettingsFromIni()
if FuncExists("HoleTriggers_EnsureInputAlive")
    try HoleTriggers_EnsureInputAlive()
; 启动时统一归一化 CapsLock 状态，避免继承系统残留 On 状态导致后续组合键流程反复恢复为大写
SetCapsLockState("Off")
try NormalizeCapsLockRuntimeForUiOpen()
catch {
}
PromptQuickPad_ReloadCapsLockBSettings()
; 初始化剪贴板数据库（在配置初始化后）
InitClipboardDB()
; 初始化 Everything 服务（在数据库初始化后）
InitEverythingService()
; 上次崩溃残留的 SearchCenterCore / 旧连接会锁住 Clipboard.db
if ProcessExist("SearchCenterCore.exe") {
    try ProcessClose("SearchCenterCore.exe")
    catch {
    }
    Sleep(400)
}
global ClipboardFTS5DB
if IsObject(ClipboardFTS5DB) && ClipboardFTS5DB {
    try ClipboardFTS5DB.CloseDB()
    catch {
    }
    ClipboardFTS5DB := 0
}
if FuncExists("Nmer_SqliteClearWalSidecars") {
    try Nmer_SqliteClearWalSidecars(Nmer_ClipboardFts5DbPath())
    catch {
    }
}
; 初始化新的剪贴板管理器数据库（FTS5）
InitClipboardFTS5DB()
; 剪贴板库就绪后再拉起 SearchCenterCore（避免 Go 进程抢先锁 Clipboard.db）
if FuncExists("Nmer_AutoStartSearchCenterCore") {
    SetTimer(Nmer_AutoStartSearchCenterCore, -1500)
    SetTimer(Nmer_AutoStartSearchCenterCore, -6000)
}
if FuncExists("Nmer_AutoStartWailsBridge") {
    SetTimer(Nmer_AutoStartWailsBridge, -3000)
}
if FuncExists("Nmer_HybridSignoffBootstrapEnsure") {
    SetTimer(Nmer_HybridSignoffBootstrapEnsure, -8000)
} else if FuncExists("Nmer_HybridManualProbeEnsure") {
    SetTimer(Nmer_HybridManualProbeEnsure, -8000)
}
if FuncExists("Nmer_MultiCardMemoryProbeEnsure") {
    SetTimer(Nmer_MultiCardMemoryProbeEnsure, -5000)
}
; 初始化粘贴板历史面板
InitClipboardHistoryPanel()
; 初始化 WebView2 剪贴板面板（尽早创建共享环境；悬浮栏/球在 _WV2_BeginWarmupAfterEnv 内应用，见上）
Global_InitAllPanels()
; 初始化悬浮工具栏
InitFloatingToolbar()
InitFloatingBubble()
; 悬浮栏/球：待 WebView2 共享环境就绪后在 _WV2_BeginWarmupAfterEnv 中 ApplyAppearanceActivationMode
; 若环境回调异常未触发，延后重试一次以免无悬浮界面（已就绪则跳过，避免二次闪烁）
SetTimer(FloatingToolbar_ApplyActivationFallback, -5000)
; 启动主脚本后自动拉起 ttyd（内部自带端口占用检测，非 ttyd 占用时会安全退出）
SetTimer(AutoStartTtydForNiumaChat, -800)
GravityPump_Register()
SelectionSense_Init()
; 加载提示词模板系统（在配置初始化后）
LoadPromptTemplates()
; 同步提示词模板到数据库
SyncPromptTemplatesToDB()
; Prompt Quick-Pad：选区采集热键（需在 CursorShortcut.ini [Settings] 中设置 PromptQuickCaptureHotkey，如 ^!p）
PromptQuickPad_RegisterCaptureHotkey()

; ===================== 剪贴板变化监听 =====================
; 注意：OnClipboardChange 必须在脚本启动时注册，确保在 InitConfig 之后定义
; 监听 Ctrl+C 复制操作，自动记录到 Ctrl+C 历史记录
global LastClipboardContent := ""  ; 记录上次剪贴板内容，避免重复记录
global CapsLockCopyInProgress := false  ; 标记 CapsLock+C 是否正在进行中
global CapsLockCopyEndTime := 0  ; CapsLock+C 结束时间，用于延迟检测
global ClipboardChangeDebounceTimer := 0  ; 剪贴板变化防抖定时器
global PendingClipboardType := 0  ; 待处理的剪贴板类型
global PendingClipboardContent := ""  ; 待处理的剪贴板内容

; 注册剪贴板变化监听器
OnClipboardChange(OnClipboardChangeHandler, 1)  ; 1 表示添加监听器

; ===================== 图片保存函数 =====================
; 图片持久化管理：使用 Gdip 将剪贴板位图保存，确保 DisposeImage 释放资源
; 路径：Cache\images\IMG_<时间>.png（见 Nmer_CacheImagesDir）
; 返回：成功返回完整路径，失败返回空字符串
SaveClipboardImage() {
    ImgDir := Nmer_CacheImagesDir()
    if !DirExist(ImgDir)
        DirCreate(ImgDir)
    
    FilePath := ImgDir "\IMG_" A_Now ".png"
    pBitmap := Gdip_CreateBitmapFromClipboard()
    if (pBitmap > 0) {
        Gdip_SaveBitmapToFile(pBitmap, FilePath)
        Gdip_DisposeImage(pBitmap)
        return FilePath
    }
    return ""
}

DeferredScreenshotHistorySave(clipData := "") {
    global ScreenshotClipboard, ClipboardDB, ClipboardFTS5DB
    data := (clipData != "") ? clipData : ScreenshotClipboard
    if (!data)
        return
    OldClip := ClipboardAll()
    try {
        A_Clipboard := data
        Sleep(80)
        imgPath := SaveClipboardImage()
        if (imgPath != "") {
            if (ClipboardDB && ClipboardDB != 0)
                SaveToDB(imgPath, "Image", "CursorHelper", "", "", StrLen(imgPath), 1)
            if (ClipboardFTS5DB && ClipboardFTS5DB != 0)
                CaptureImageFileToFTS5(imgPath, "CursorHelper")
        }
    } catch {
    }
    try {
        A_Clipboard := OldClip
    } catch {
    }
}

; ===================== 规范入库与排重函数 =====================
; ===================== 智能分拣剪贴板内容 =====================
; 对文本进行智能分类和环境捕获
ClassifyClipboardContent(content) {
    ; 初始化返回结果
    result := Map()
    result["DataType"] := "Text"
    result["CharCount"] := 0
    result["WordCount"] := 0
    
    ; 如果内容为空，返回默认值
    if (content = "" || StrLen(content) = 0) {
        return result
    }
    
    ; 计算字符数和词数
    trimmedContent := Trim(content, " `t`r`n")
    result["CharCount"] := StrLen(trimmedContent)
    
    ; 计算词数（去除标点符号后按空格分割）
    words := StrSplit(RegExReplace(trimmedContent, "[^\w\s]+", ""), " ")
    result["WordCount"] := words.Length
    
    ; 智能分类：对选中的文本进行正则判定
    ; 1. 链接检测 (Link)
    if (RegExMatch(trimmedContent, "i)^(https?:\/\/|www\.)[^\s]+$")) {
        result["DataType"] := "Link"
    }
    ; 2. 邮箱检测 (Email)
    else if (RegExMatch(trimmedContent, "i)^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$")) {
        result["DataType"] := "Email"
    }
    ; 3. 代码检测 (Code) - 检测常见的代码特征
    else if (RegExMatch(trimmedContent, "[\{\}\[\]\(\);]|=>|:=|function|const|import|class|def|return|var|let")) {
        result["DataType"] := "Code"
    }
    ; 4. 默认文本 (Text)
    else {
        result["DataType"] := "Text"
    }
    
    return result
}

; ===================== 捕获环境信息 =====================
CaptureEnvironmentInfo() {
    envInfo := Map()
    envInfo["SourceApp"] := "Unknown"
    envInfo["SourceTitle"] := ""
    envInfo["SourcePath"] := ""
    
    try {
        ; 获取当前活动窗口ID
        ActiveID := WinGetID("A")
        
        ; 获取进程名
        try {
            envInfo["SourceApp"] := WinGetProcessName(ActiveID)
        } catch as err {
            envInfo["SourceApp"] := "Unknown"
        }
        
        ; 获取窗口标题
        try {
            envInfo["SourceTitle"] := WinGetTitle(ActiveID)
        } catch as err {
            envInfo["SourceTitle"] := ""
        }
        
        ; 获取进程路径
        try {
            envInfo["SourcePath"] := WinGetProcessPath(ActiveID)
        } catch as err {
            envInfo["SourcePath"] := ""
        }
    } catch as e {
        ; 捕获失败，使用默认值
    }
    
    return envInfo
}

; ===================== 保存剪贴板数据到数据库（11字段架构，废弃 SessionID 模式） =====================
SaveToDB(content, type, app, title, path, cCount, wCount) {
    global ClipboardDB  ; 必须声明全局，否则函数内部找不到数据库句柄
    if (!ClipboardDB || ClipboardDB = 0) {
        InitClipboardDB() ; 如果连接断开，尝试重新初始化
    }

    ; 排重检查：获取最后一条内容
    try {
        recordSet := ClipboardDB.GetTable("SELECT Content FROM ClipboardHistory ORDER BY ID DESC LIMIT 1")
        if (recordSet.HasNames && recordSet.Rows.Length > 0 && recordSet.Rows[1][1] = content)
            return ; 内容重复，直接返回不写入
    }

    ; 构造 SQL：严格按照 11 字段架构，禁止手动插入 ID（由 AUTOINCREMENT 自动处理）
    sql := "INSERT INTO ClipboardHistory " .
           "(Content, DataType, SourceApp, SourceTitle, SourcePath, CharCount, WordCount, Timestamp) " .
           "VALUES (" .
           "'" . StrReplace(content, "'", "''") . "', " .
           "'" . type . "', " .
           "'" . StrReplace(app, "'", "''") . "', " .
           "'" . StrReplace(title, "'", "''") . "', " .
           "'" . StrReplace(path, "'", "''") . "', " .
           cCount . ", " . wCount . ", " .
           "datetime('now', 'localtime'))"

    try {
        ClipboardDB.Exec(sql) ; 执行物理写入
    } catch as err {
        ; 记录错误日志，防止静默失败
        FileAppend(A_Now ": SQL Error " err.Message "`n", "db_error.log")
    }
}

; ===================== 剪贴板变化监听器（带防抖功能）=====================
; 回调函数，用于注册到 OnClipboardChange
; 具备防抖功能：在短时间内多次触发时，只执行最后一次
OnClipboardChangeHandler(Type) {
    global ClipboardDB, ClipboardFTS5DB, CapsLockCopyInProgress
    global ClipboardChangeDebounceTimer, PendingClipboardType, PendingClipboardContent
    global ScreenshotWaiting, ScreenshotImageDetected, ScreenshotClipboard, ScreenshotLastFilePath
    try OutputDebug("[CLIP] change type=" . Type . " waiting=" . (ScreenshotWaiting ? "1" : "0") . " detected=" . (ScreenshotImageDetected ? "1" : "0"))
    catch {
    }

    if (CapsLockCopyInProgress) {
        return
    }

    ; 截图等待期间：图片写入剪贴板时立即通知检测循环，跳过常规处理以避免剪贴板竞争
    if (ScreenshotWaiting && Type = 2) {
        try {
            ScreenshotClipboard := ClipboardAll()
        } catch {
            ScreenshotClipboard := ""
        }
        try {
            files := GetClipboardFileDropList()
            if (files != "") {
                firstPath := StrSplit(files, "`n")[1]
                if (firstPath != "")
                    ScreenshotLastFilePath := firstPath
            } else {
                txt := Trim(String(A_Clipboard))
                if (txt != "" && FileExist(txt))
                    ScreenshotLastFilePath := txt
            }
        } catch {
        }
        ScreenshotImageDetected := true
        try OutputDebug("[CLIP] screenshot image detected type=2")
        catch {
        }
        return
    }

    if (Type = 0 || A_PtrSize = "")
        return

    ; 防抖处理：清除之前的定时器
    if (ClipboardChangeDebounceTimer != 0) {
        try {
            SetTimer(ClipboardChangeDebounceTimer, 0)  ; 清除定时器
        } catch {
        }
    }

    ; 保存当前剪贴板类型和内容（用于防抖延迟执行）
    PendingClipboardType := Type
    if (Type = 1) { ; 文本类型
        try {
            PendingClipboardContent := A_Clipboard
        } catch {
            PendingClipboardContent := ""
        }
    } else {
        PendingClipboardContent := ""
    }

    ; 设置防抖定时器（300毫秒延迟，避免频繁触发）
    ClipboardChangeDebounceTimer := (*) => ProcessClipboardChange()
    SetTimer(ClipboardChangeDebounceTimer, -300)  ; 300毫秒后执行
}

GetClipboardFileDropList() {
    fileList := ""
    cfHDrop := 15
    if !DllCall("OpenClipboard", "Ptr", 0)
        return ""
    try {
        hDrop := DllCall("GetClipboardData", "UInt", cfHDrop, "Ptr")
        if !hDrop
            return ""
        fileCount := DllCall("Shell32\DragQueryFileW", "Ptr", hDrop, "UInt", 0xFFFFFFFF, "Ptr", 0, "UInt", 0, "UInt")
        if (fileCount < 1)
            return ""
        Loop fileCount {
            pathLen := DllCall("Shell32\DragQueryFileW", "Ptr", hDrop, "UInt", A_Index - 1, "Ptr", 0, "UInt", 0, "UInt")
            if (pathLen < 1)
                continue
            buf := Buffer((pathLen + 1) * 2, 0)
            readLen := DllCall("Shell32\DragQueryFileW", "Ptr", hDrop, "UInt", A_Index - 1, "Ptr", buf.Ptr, "UInt", pathLen + 1, "UInt")
            if (readLen < 1)
                continue
            onePath := StrGet(buf, "UTF-16")
            if (onePath != "")
                fileList .= (fileList = "" ? "" : "`n") . onePath
        }
    } finally {
        DllCall("CloseClipboard")
    }
    return fileList
}

; ===================== 处理剪贴板变化（防抖后的实际处理函数）=====================
ProcessClipboardChange() {
    global ClipboardDB, ClipboardFTS5DB, PendingClipboardType, PendingClipboardContent

    Type := PendingClipboardType
    if (Type = 0 || A_PtrSize = "")
        return

    try {
        ; 1. 捕获环境信息（获取当前活动窗口的进程名）
        SourceApp := "Unknown"
        SourceTitle := ""
        SourcePath := ""
        
        try {
            ActiveID := WinGetID("A")
            SourceApp := WinGetProcessName(ActiveID)
            SourceTitle := WinGetTitle(ActiveID)
            SourcePath := WinGetProcessPath(ActiveID)
        } catch {
            SourceApp := "Unknown"
        }

        dataType := "Text", content := "", charCount := 0, wordCount := 0
        clipImageFiles := GetClipboardFileDropList()  ; 先统一检查 CF_HDROP，避免资源管理器复制图片文件被误判成文本

        if (Type = 1) { ; 文本
            ; 防抖延迟内剪贴板可能被其它程序改写，优先用 OnClipboardChange 瞬间快照
            raw := ""
            if (PendingClipboardContent != "")
                raw := PendingClipboardContent
            else {
                try raw := A_Clipboard
                catch
                    raw := ""
            }
            content := ClipboardFTS5_NormalizeCapturedText(raw)
            ; 其它进程占用剪贴板时 A_Clipboard 可能短暂为空，短重试
            if (content = "") {
                Loop 6 {
                    Sleep(35)
                    try raw := A_Clipboard
                    catch
                        raw := ""
                    content := ClipboardFTS5_NormalizeCapturedText(raw)
                    if (content != "")
                        break
                }
            }
            charCount := StrLen(content)
            wordCount := StrSplit(RegExReplace(content, "[^\w\s]+", ""), " ").Length

            ; 智能分拣
            if RegExMatch(content, "i)^(https?:\/\/|www\.)[^\s]+$")
                dataType := "Link"
            else if RegExMatch(content, "i)^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$")
                dataType := "Email"
            else if RegExMatch(content, "[\{\}\[\]\(\);]|=>|:=|function|const|import")
                dataType := "Code"

            if (clipImageFiles != "") {
                dataType := "File"
                content := clipImageFiles
                charCount := StrLen(content)
                FileLines := StrSplit(content, "`n")
                wordCount := FileLines.Length
            }

        } else if (Type = 2) { ; 图片或文件
            files := clipImageFiles
            if (files = "") {
                try {
                    ClipboardObj := WinClip()
                    files := ClipboardObj.GetFiles()
                } catch {
                    files := ""
                }
            }
            if (files) {
                dataType := "File"
                content := files
                clipImageFiles := files
                charCount := StrLen(content)
                FileLines := StrSplit(files, "`n")
                wordCount := FileLines.Length
            } else {
                dataType := "Image"
                content := SaveClipboardImage() ; 调用下方保存函数
                if (content != "") {
                    charCount := StrLen(content)
                    wordCount := 1  ; 图片计为1个"词"
                }
            }
        }

        if (content != "") {
            ; 保存到旧的数据库系统（用于现有的剪贴板管理器）
            if (ClipboardDB && ClipboardDB != 0) {
                SaveToDB(content, dataType, SourceApp, SourceTitle, SourcePath, charCount, wordCount)
            }
        }

        ; ===== FTS5 新剪贴板面板入库（Raycast 风格：按剪贴板格式独立检测，不依赖 Type） =====
        if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
            ftsOk := false

            ; 优先级 1：CF_HDROP 文件拖放（资源管理器复制文件）
            if (clipImageFiles != "") {
                ftsOk := ClipboardFTS5_ImportDroppedImageFiles(clipImageFiles, SourceApp)
            }

            ; 优先级 2：内容非空
            ; - Image：优先按本地图片文件入库（兼容 Type=2 时 SaveClipboardImage 返回路径）
            ; - 其它：走文本入库（SaveToClipboardFTS5 内部识别图片 URL/路径）
            if (!ftsOk && content != "") {
                if (dataType = "Image") {
                    localImg := ClipboardFTS5_SingleLocalImagePathFromText(content)
                    if (localImg != "") {
                        ftsOk := CaptureImageFileToFTS5(localImg, SourceApp)
                    }
                } else {
                    localImg := ClipboardFTS5_SingleLocalImagePathFromText(content)
                    if (localImg != "") {
                        ftsOk := CaptureImageFileToFTS5(localImg, SourceApp)
                    } else {
                        ftsOk := SaveToClipboardFTS5(content, SourceApp)
                    }
                }
            }

            ; 优先级 2.5：已判定为图片但仍未入库，直接尝试剪贴板位图采集
            if (!ftsOk && dataType = "Image") {
                sourceUrl := ""
                try sourceUrl := _ClipboardFTS5_GetClipboardHtmlImageRef()
                ftsOk := CaptureClipboardImageToFTS5(SourceApp, sourceUrl)
            }

            ; 优先级 3：文本为空或为刚才后台保存的位图 → 浏览器/应用纯图片复制（CF_DIB=8, CF_BITMAP=2）
            if (!ftsOk) {
                if (DllCall("IsClipboardFormatAvailable", "UInt", 8)
                    || DllCall("IsClipboardFormatAvailable", "UInt", 2)) {
                    
                    ; 尝试获取图片源地址（适用于从浏览器中复制图片）
                    sourceUrl := ""
                    try sourceUrl := _ClipboardFTS5_GetClipboardHtmlImageRef()
                    
                    ftsOk := CaptureClipboardImageToFTS5(SourceApp, sourceUrl)
                }
            }

            if (ftsOk)
                try CP_NotifyClipboardUpdated()

            ; 如果 ClipboardHistoryPanel 已显示，自动刷新数据
            try {
                global HistoryIsVisible
                if (IsSet(HistoryIsVisible) && HistoryIsVisible) {
                    SetTimer(() => RefreshHistoryData(), -300)
                }
            } catch {
            }
        }
    } catch as err {
        ; 静默处理错误，避免影响其他功能
    }
}

; VirtualKeyboardCore 在热键块之后才 #Include；CapsLock 和弦会先调到 VK_*，须提前声明
global g_VK_TextInputActive := false

; 快捷操作面板与提示词执行（模块化）
#Include modules\CursorPanelController.ahk
#Include modules\PromptExecution.ahk

#Include "modules\LegacyConfigGui.ahk"
#Include "modules\LegacyClipboardListView.ahk"
; ConfigWebViewModule 须在 VirtualKeyboardCore 之后 #Include（见文件末尾）

ShowConfigGUI_Core() {
    global UseWebViewSettings
    if (UseWebViewSettings) {
        SurfaceIntent_Open("config_webview")
        return
    }
    LegacyConfigGui_Show()
}

ShowConfigGUI() {
    ; Route all legacy callers through safe open path.
    ShowConfigGUI_Safe()
}

ShowConfigGUI_FallbackCheck(*) {
    static retryCount := 0
    global GuiID_ConfigGUI, UseWebViewSettings, g_ConfigWebViewOpenStartTick, g_ConfigPreferWebViewOnly, g_ConfigOpenInFlight, g_ConfigUserClosedTick
    ; User explicitly closed settings recently: never auto-reopen.
    if (g_ConfigUserClosedTick > 0 && (A_TickCount - g_ConfigUserClosedTick) < 3000) {
        retryCount := 0
        return
    }
    ; No active opening session => stop fallback loop.
    if (g_ConfigWebViewOpenStartTick <= 0 && !g_ConfigOpenInFlight) {
        retryCount := 0
        return
    }
    ; If WebView config host is still unavailable after safe open,
    ; fall back to legacy config window to guarantee accessibility.
    try {
        if (ThemeApply_IsInProgress() || ActivationApply_IsInProgress()) {
            if (retryCount < 8) {
                retryCount += 1
                SetTimer(ShowConfigGUI_FallbackCheck, -180)
                return
            }
        } else {
            retryCount := 0
        }
    } catch {
    }
    try {
        if (g_ConfigWebViewOpenStartTick > 0) {
            elapsed := A_TickCount - g_ConfigWebViewOpenStartTick
            if (elapsed < 2400) {
                retryCount += 1
                SetTimer(ShowConfigGUI_FallbackCheck, -220)
                return
            }
        }
    } catch {
    }
    try {
        if (GuiID_ConfigGUI && WinExist("ahk_id " . GuiID_ConfigGUI.Hwnd)) {
            vis := false
            try vis := (WinGetStyle("ahk_id " . GuiID_ConfigGUI.Hwnd) & 0x10000000)
            if vis
            {
                retryCount := 0
                g_ConfigWebViewOpenStartTick := 0
                return
            }
        }
    }
    catch {
    }
    if (g_ConfigPreferWebViewOnly) {
        try {
            ; Prefer recovering WebView settings host instead of bouncing to legacy page.
            if (g_ConfigOpenInFlight) {
                retryCount += 1
                if (retryCount <= 12) {
                    SetTimer(ShowConfigGUI_FallbackCheck, -260)
                    return
                }
            }
        } catch {
        }
    }
    try {
        if FuncExists("ConfigWebView_ReleaseSettingsDock")
            ConfigWebView_ReleaseSettingsDock("recover")
    } catch {
    }
    if (g_ConfigPreferWebViewOnly) {
        try SetTimer((*) => SurfaceIntent_Open("config_webview"), -120)
        g_ConfigWebViewOpenStartTick := A_TickCount
        retryCount += 1
        if (retryCount <= 12)
            SetTimer(ShowConfigGUI_FallbackCheck, -260)
        return
    }
    g_ConfigWebViewOpenStartTick := 0
    LegacyConfigGui_Show()
}

NormalizeCapsLockRuntimeForUiOpen() {
    global CapsLock, CapsLock2, VKHoldVisible, CapsLockDownTime
    ; Ensure UI entry (tray/settings) does not leave CapsLock chord mode active.
    try CapsLock := false
    try CapsLock2 := false
    try VKHoldVisible := false
    try CapsLockDownTime := 0
    try Send("{CapsLock up}")
    try SetCapsLockState("Off")
}

ShowConfigGUI_Safe() {
    global g_ConfigWebViewOpenStartTick, g_ConfigOpenInFlight, g_ConfigOpenInFlightSince, g_ConfigUserClosedTick, g_ConfigOpenEntryMode
    NMER_Log("ui", "open_config_safe_begin", "")
    nowTick := A_TickCount
    ; Recover from stale/invisible config host left by failed dark-mode close.
    try {
        if (GuiID_ConfigGUI && WinExist("ahk_id " . GuiID_ConfigGUI.Hwnd)) {
            vis0 := (WinGetStyle("ahk_id " . GuiID_ConfigGUI.Hwnd) & 0x10000000)
            if (!vis0) {
                g_ConfigWebViewOpenStartTick := 0
                g_ConfigOpenInFlight := false
                g_ConfigOpenInFlightSince := 0
                NMER_Log("ui", "open_config_recover_stale_host", "")
            }
        }
    } catch {
    }
    if (g_ConfigOpenInFlight && (nowTick - g_ConfigOpenInFlightSince) < 2500) {
        NMER_Log("ui", "open_config_safe_skip_inflight", "elapsed_ms=" . (nowTick - g_ConfigOpenInFlightSince))
        return
    }
    g_ConfigOpenInFlight := true
    g_ConfigOpenInFlightSince := nowTick
    g_ConfigUserClosedTick := 0
    try g_ConfigOpenEntryMode := NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar")
    catch
        g_ConfigOpenEntryMode := "toolbar"
    try NormalizeCapsLockRuntimeForUiOpen()
    catch {
    }
    try {
        if (ThemeApply_IsInProgress() || ActivationApply_IsInProgress()) {
            NMER_Log("ui", "open_config_deferred_busy", "theme=" . (ThemeApply_IsInProgress() ? "1" : "0") . " activation=" . (ActivationApply_IsInProgress() ? "1" : "0"))
            SetTimer(ShowConfigGUI_Safe, -220)
            return
        }
    }
    catch {
    }
    g_ConfigWebViewOpenStartTick := A_TickCount
    ; Defensive open path: clear overlay/runtime interference before showing settings.
    try GDHO_UnpinFromDesktop()
    catch {
    }
    try GDHO_SetClickThrough(true)
    catch {
    }
    ; Avoid tearing down the whole hole runtime when opening menus/settings.
    ; Stopping the bridge here can trigger a visible white fallback and add startup lag.
    try NativeDropBridge_SetSilentMode(true, "config_open")
    catch {
    }
    try GDHO_DisarmPolling("config_open")
    catch {
    }
    try GDHO_HideFrontend()
    catch {
    }
    try GDHO_HideOverlay()
    catch {
    }
    try SurfaceIntent_Close("floating_toolbar")
    catch {
    }
    try HideFloatingBubble()
    catch {
    }
    ; Open settings async to avoid re-entrancy from menu/hotkey callbacks.
    delayMs := 20
    try {
        if (NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar") = "hole")
            delayMs := 140
    } catch {
    }
    try SetTimer((*) => ShowConfigGUI_Core(), -delayMs)
    catch {
        try ShowConfigGUI_Core()
    }
    ; Fallback safety net: if WebView path fails, open legacy settings.
    try SetTimer(ShowConfigGUI_FallbackCheck, -900)
    try SetTimer(ConfigOpenFlightRelease, -2600)
    NMER_Log("ui", "open_config_safe_scheduled", "")
}

ConfigOpenFlightRelease(*) {
    global g_ConfigOpenInFlight, g_ConfigOpenInFlightSince
    global g_ConfigWebViewOpenStartTick, g_ConfigUserClosedTick
    global ConfigWebViewMode, GuiID_ConfigGUI
    global TrayMenuCustomFailStreak, TrayMenuSuppressNativeFallbackUntil
    g_ConfigOpenInFlight := false
    g_ConfigOpenInFlightSince := 0
    ; If settings window failed to close/render callback, force-release stuck state
    ; so user can reopen settings and tray menu won't keep degrading to native white menu.
    vis := false
    try {
        if (GuiID_ConfigGUI && WinExist("ahk_id " . GuiID_ConfigGUI.Hwnd))
            vis := (WinGetStyle("ahk_id " . GuiID_ConfigGUI.Hwnd) & 0x10000000)
    } catch {
        vis := false
    }
    if (!vis) {
        g_ConfigWebViewOpenStartTick := 0
        if (ConfigWebViewMode)
            g_ConfigUserClosedTick := A_TickCount
        try SetTimer(ShowConfigGUI_FallbackCheck, 0)
        try SetTimer(RestoreActivationRuntimeAfterConfigClose, -80)
        TrayMenuCustomFailStreak := 0
        TrayMenuSuppressNativeFallbackUntil := A_TickCount + 1800
        NMER_Log("ui", "open_config_force_release", "vis=0")
    } else {
        NMER_Log("ui", "open_config_force_release", "vis=1")
    }
}

; ===================== 保存剪贴板管理器窗口位置 =====================
SaveClipboardManagerPosition() {
    global GuiID_ClipboardManager
    try {
        ; 检查窗口是否还存在
        if (!GuiID_ClipboardManager || GuiID_ClipboardManager = 0) {
            ; 窗口已关闭，停止定时器并立即保存所有待保存的位置
            SetTimer(() => SaveClipboardManagerPosition(), 0)
            FlushPendingWindowPositions()
            return
        }
        
        ; 获取窗口位置和大小
        WinGetPos(&WinX, &WinY, &WinW, &WinH, GuiID_ClipboardManager.Hwnd)
        WindowName := "📋 " . GetText("clipboard_manager")
        ; 使用延迟保存，统一管理
        QueueWindowPositionSave(WindowName, WinX, WinY, WinW, WinH)
    } catch as err {
        ; 忽略错误（窗口可能已关闭）
    }
}


; 关闭配置面板
CloseConfigGUI() {
    global CloseConfigGUI_IsClosing
    global GuiID_ConfigGUI, CapsLockHoldTimeEdit, CapsLockHoldTimeSeconds, ConfigFile
    global DDLBrush, DefaultStartTabDDL_Hwnd
    global ConfigWebViewMode, ConfigWV2Ctrl, ConfigWV2, ConfigWV2Ready
    global g_ConfigOpenInFlight, g_ConfigWebViewOpenStartTick, g_ConfigUserClosedTick

    ; 如果正在关闭，直接返回
    if (CloseConfigGUI_IsClosing) {
        return
    }
    
    ; 如果窗口已经不存在，直接返回
    if (GuiID_ConfigGUI = 0) {
        CloseConfigGUI_IsClosing := false
        return
    }

    ; WebView 设置页关闭路径（首期改造）
    if (ConfigWebViewMode) {
        reqId := SurfaceManager_Request("config_webview", "close", "CloseConfigGUI", Map("mode", "webview"))
        try SurfaceManager_ObserveHide("config_webview", Map("entry", "CloseConfigGUI", "mode", "webview", "requestId", reqId))
        g_ConfigUserClosedTick := A_TickCount
        g_ConfigOpenInFlight := false
        g_ConfigWebViewOpenStartTick := 0
        try SetTimer(ShowConfigGUI_FallbackCheck, 0)
        SurfaceIntent_Close("config_webview")
        ; Restore activation runtime (especially hole mode bridge/overlay) after settings close.
        try SetTimer(RestoreActivationRuntimeAfterConfigClose, -120)
        SetTimer(LegacyConfigGui_ClearClosingFlag, -100)
        return
    }
    
    LegacyConfigGui_CloseNative()
}

; ===================== 图标切换功能 =====================
ChangeCustomIcon(*) {
    global CustomIconPath, GuiID_ConfigGUI, SearchIcon, ConfigFile
    
    ; 打开文件选择对话框，只允许选择图片文件
    SelectedFile := FileSelect("1", A_ScriptDir, "选择图标文件", "图片文件 (*.ico; *.png; *.jpg; *.jpeg; *.bmp)")
    
    if (SelectedFile = "") {
        return  ; 用户取消了选择
    }
    
    ; 验证文件是否存在
    if (!FileExist(SelectedFile)) {
        MsgBox("文件不存在: " . SelectedFile, "错误", "Iconx")
        return
    }
    
    ; 更新全局变量
    CustomIconPath := SelectedFile
    
    ; 更新配置面板中的图标
    if (GuiID_ConfigGUI && SearchIcon) {
        try {
            ; 重新设置图标图片
            SearchIcon.Value := SelectedFile
            SearchIcon.Redraw()
        } catch as e {
            ; 如果更新失败，尝试重新创建图标控件
            try {
                ; 获取图标位置和大小
                IconX := 10
                IconY := 45
                IconSize := 32
                ; 删除旧图标
                SearchIcon.Destroy()
                ; 创建新图标
                global ConfigGUI
                ConfigGUI := GuiFromHwnd(GuiID_ConfigGUI)
                if (ConfigGUI) {
                    SearchIcon := ConfigGUI.Add("Picture", "x" . IconX . " y" . IconY . " w" . IconSize . " h" . IconSize . " 0x200 BackgroundTrans vConfigIcon", SelectedFile)
                    SearchIcon.OnEvent("Click", (*) => ChangeCustomIcon())
                    SearchIcon.Opt("+E0x200")
                }
            } catch as err {
                MsgBox("更新图标失败: " . e.Message, "错误", "Iconx")
            }
        }
    }
    
    ; 更新托盘图标
    UpdateTrayIcon()
    
    ; 保存配置（延迟保存，避免频繁IO）
    SetTimer((*) => SaveIconConfig(), -500)
}

; 保存图标配置
SaveIconConfig() {
    global CustomIconPath, ConfigFile
    if (IsSet(CustomIconPath)) {
        if (CustomIconPath != "" && FileExist(CustomIconPath)) {
            IniWrite(CustomIconPath, ConfigFile, "Settings", "CustomIconPath")
        } else {
            IniWrite("", ConfigFile, "Settings", "CustomIconPath")
        }
    }
}

; 更新托盘图标：见 modules\TrayMenuManager.ahk 中的 UpdateTrayIcon()

; ===================== 保存配置函数 =====================
SaveConfig(*) {
    global AISleepTimeEdit, PanelScreenRadio, CapsLockHoldTimeEdit
    global CursorPathEdit, PromptExplainEdit, PromptRefactorEdit, PromptOptimizeEdit
    global LangChinese, ConfigFile, GuiID_CursorPanel, GuiID_ConfigGUI
    global ConfigPanelScreenRadio, MsgBoxScreenRadio, VoiceInputScreenRadio, CursorPanelScreenRadio
    global PanelVisible, ThemeLightRadio, ThemeDarkRadio
    
    ; 验证输入
    if (!AISleepTimeEdit || AISleepTimeEdit.Value = "" || !IsNumber(AISleepTimeEdit.Value)) {
        MsgBox(GetText("ai_wait_time_error"), GetText("error"), "Iconx")
        return false
    }
    
    ; 验证CapsLock长按时间
    if (CapsLockHoldTimeEdit && CapsLockHoldTimeEdit.Value != "") {
        NewHoldTime := Float(CapsLockHoldTimeEdit.Value)
        if (!IsNumber(NewHoldTime) || NewHoldTime < 0.1 || NewHoldTime > 5.0) {
            MsgBox(GetText("capslock_hold_time_error"), GetText("error"), "Iconx")
            return false
        }
    }
    
    ; 解析屏幕索引（Radio 按钮组）
    NewScreenIndex := 1
    if (PanelScreenRadio && PanelScreenRadio.Length > 0) {
        for Index, RadioBtn in PanelScreenRadio {
            if (RadioBtn.HasProp("IsSelected") && RadioBtn.IsSelected) {
                NewScreenIndex := Index
                break
            }
        }
    }
    if (NewScreenIndex < 1) {
        NewScreenIndex := 1
    }
    
    ; 获取语言设置
    NewLanguage := (LangChinese && LangChinese.HasProp("IsSelected") && LangChinese.IsSelected) ? "zh" : "en"
    
    ; 解析高级设置中的屏幕索引
    NewConfigPanelScreenIndex := 1
    if (ConfigPanelScreenRadio && ConfigPanelScreenRadio.Length > 0) {
        for Index, RadioBtn in ConfigPanelScreenRadio {
            if (RadioBtn.HasProp("IsSelected") && RadioBtn.IsSelected) {
                NewConfigPanelScreenIndex := Index
                break
            }
        }
    }
    if (NewConfigPanelScreenIndex < 1) {
        NewConfigPanelScreenIndex := 1
    }
    
    NewMsgBoxScreenIndex := 1
    if (MsgBoxScreenRadio && MsgBoxScreenRadio.Length > 0) {
        for Index, RadioBtn in MsgBoxScreenRadio {
            if (RadioBtn.HasProp("IsSelected") && RadioBtn.IsSelected) {
                NewMsgBoxScreenIndex := Index
                break
            }
        }
    }
    if (NewMsgBoxScreenIndex < 1) {
        NewMsgBoxScreenIndex := 1
    }
    
    NewVoiceInputScreenIndex := 1
    if (VoiceInputScreenRadio && VoiceInputScreenRadio.Length > 0) {
        for Index, RadioBtn in VoiceInputScreenRadio {
            if (RadioBtn.HasProp("IsSelected") && RadioBtn.IsSelected) {
                NewVoiceInputScreenIndex := Index
                break
            }
        }
    }
    if (NewVoiceInputScreenIndex < 1) {
        NewVoiceInputScreenIndex := 1
    }
    
    NewCursorPanelScreenIndex := 1
    if (CursorPanelScreenRadio && CursorPanelScreenRadio.Length > 0) {
        for Index, RadioBtn in CursorPanelScreenRadio {
            if (RadioBtn.HasProp("IsSelected") && RadioBtn.IsSelected) {
                NewCursorPanelScreenIndex := Index
                break
            }
        }
    }
    if (NewCursorPanelScreenIndex < 1) {
        NewCursorPanelScreenIndex := 1
    }
    
    NewClipboardPanelScreenIndex := 1
    global ClipboardPanelScreenRadio
    if (ClipboardPanelScreenRadio && ClipboardPanelScreenRadio.Length > 0) {
        for Index, RadioBtn in ClipboardPanelScreenRadio {
            if (RadioBtn.HasProp("IsSelected") && RadioBtn.IsSelected) {
                NewClipboardPanelScreenIndex := Index
                break
            }
        }
    }
    if (NewClipboardPanelScreenIndex < 1) {
        NewClipboardPanelScreenIndex := 1
    }
    
    ; 获取主题模式设置
    NewThemeMode := "dark"
    ; 如果外观标签页已创建，从单选按钮读取；否则使用当前主题模式
    if (IsSet(ThemeLightRadio) && ThemeLightRadio && IsObject(ThemeLightRadio) && ThemeLightRadio.HasProp("IsSelected") && ThemeLightRadio.IsSelected) {
        NewThemeMode := "light"
    } else if (IsSet(ThemeDarkRadio) && ThemeDarkRadio && IsObject(ThemeDarkRadio) && ThemeDarkRadio.HasProp("IsSelected") && ThemeDarkRadio.IsSelected) {
        NewThemeMode := "dark"
    } else {
        ; 如果控件不存在，使用当前主题模式
        global ThemeMode
        NewThemeMode := ThemeMode
    }
    global ThemeMode
    if (ThemeMode != NewThemeMode) {
        ThemeMode := NewThemeMode
        ApplyTheme(NewThemeMode)
    }
    
    ; 更新全局变量
    global CursorPath := NormalizeWindowsPath(CursorPathEdit ? CursorPathEdit.Value : "")
    global AISleepTime := AISleepTimeEdit.Value
    ; 【修复】确保CapsLock长按时间正确保存：优先使用编辑框的值，如果为空则使用当前全局变量的值（不重置为默认值）
    if (CapsLockHoldTimeEdit && CapsLockHoldTimeEdit.Value != "") {
        global CapsLockHoldTimeSeconds := Float(CapsLockHoldTimeEdit.Value)
        ; 确保值在合理范围内
        if (CapsLockHoldTimeSeconds < 0.1) {
            CapsLockHoldTimeSeconds := 0.1
        } else if (CapsLockHoldTimeSeconds > 5.0) {
            CapsLockHoldTimeSeconds := 5.0
        }
    } else {
        ; 如果编辑框为空，保持当前全局变量的值（不重置为默认值）
        if (!IsSet(CapsLockHoldTimeSeconds) || CapsLockHoldTimeSeconds = "") {
            global CapsLockHoldTimeSeconds := 0.5  ; 只有在完全未设置时才使用默认值
        }
    }
    global Prompt_Explain := PromptExplainEdit ? PromptExplainEdit.Value : ""
    global Prompt_Refactor := PromptRefactorEdit ? PromptRefactorEdit.Value : ""
    global Prompt_Optimize := PromptOptimizeEdit ? PromptOptimizeEdit.Value : ""
    ; 读取倒计时延迟时间
    global LaunchDelaySeconds, LaunchDelaySecondsEdit
    if (LaunchDelaySecondsEdit && LaunchDelaySecondsEdit.Value != "") {
        LaunchDelaySeconds := Float(LaunchDelaySecondsEdit.Value)
        ; 确保值在合理范围内（0.5秒到10秒）
        if (LaunchDelaySeconds < 0.5) {
            LaunchDelaySeconds := 0.5
        } else if (LaunchDelaySeconds > 10.0) {
            LaunchDelaySeconds := 10.0
        }
    } else {
        ; 如果编辑框为空，保持当前全局变量的值
        if (!IsSet(LaunchDelaySeconds) || LaunchDelaySeconds = "") {
            LaunchDelaySeconds := 3.0  ; 只有在完全未设置时才使用默认值
        }
    }
    global PanelScreenIndex := NewScreenIndex
    global Language := NewLanguage
    global ConfigPanelScreenIndex := NewConfigPanelScreenIndex
    global MsgBoxScreenIndex := NewMsgBoxScreenIndex
    global VoiceInputScreenIndex := NewVoiceInputScreenIndex
    global CursorPanelScreenIndex := NewCursorPanelScreenIndex
    global ClipboardPanelScreenIndex := NewClipboardPanelScreenIndex
    
    ; 读取默认启动页面设置（从下拉框读取）
    global DefaultStartTab, DefaultStartTabDDL
    if (DefaultStartTabDDL && DefaultStartTabDDL.Value) {
        StartTabOptions := ["general", "appearance", "prompts", "hotkeys", "advanced"]
        if (DefaultStartTabDDL.Value >= 1 && DefaultStartTabDDL.Value <= StartTabOptions.Length) {
            DefaultStartTab := StartTabOptions[DefaultStartTabDDL.Value]
        } else {
            DefaultStartTab := "general"
        }
    } else {
        DefaultStartTab := "general"
    }
    
    ; 读取自启动设置（从按钮状态读取，已在ToggleAutoStart中更新）
    global AutoStart
    
    ; 保存到配置文件
    IniWrite(CursorPath, ConfigFile, "Settings", "CursorPath")
    IniWrite(AISleepTime, ConfigFile, "Settings", "AISleepTime")
    ; 【修复】使用字符串格式保存，确保精度和一致性
    IniWrite(String(CapsLockHoldTimeSeconds), ConfigFile, "Settings", "CapsLockHoldTimeSeconds")
    IniWrite(String(LaunchDelaySeconds), ConfigFile, "Settings", "LaunchDelaySeconds")
    IniWrite(Prompt_Explain, ConfigFile, "Settings", "Prompt_Explain")
    IniWrite(Prompt_Refactor, ConfigFile, "Settings", "Prompt_Refactor")
    IniWrite(Prompt_Optimize, ConfigFile, "Settings", "Prompt_Optimize")
    
    ; 保存提示词模板系统
    SavePromptTemplates()
    IniWrite(PanelScreenIndex, ConfigFile, "Panel", "ScreenIndex")
    IniWrite(Language, ConfigFile, "Settings", "Language")
    IniWrite(ThemeMode, ConfigFile, "Settings", "ThemeMode")
    IniWrite(ThemeMode, ConfigFile, "Appearance", "ThemeMode")
    
    ; 主题已更改，需要重新创建所有面板以应用新主题
    ; 注意：这里不立即重新创建，因为用户可能还在查看配置面板
    ; 主题会在下次打开面板时自动应用
    
    global AutoLoadSelectedText, AutoStart, VoiceSearchEnabledCategories
    IniWrite(AutoLoadSelectedText ? "1" : "0", ConfigFile, "Settings", "AutoLoadSelectedText")
    IniWrite(AutoStart ? "1" : "0", ConfigFile, "Settings", "AutoStart")
    
    ; 保存默认启动页面设置
    global DefaultStartTab
    if (IsSet(DefaultStartTab) && DefaultStartTab != "") {
        if FuncExists("NormalizeDefaultStartTab")
            DefaultStartTab := NormalizeDefaultStartTab(DefaultStartTab)
        IniWrite(DefaultStartTab, ConfigFile, "Settings", "DefaultStartTab")
    } else {
        IniWrite("general", ConfigFile, "Settings", "DefaultStartTab")
    }
    
    ; 保存 Cursor 规则内容
    try {
        if (GuiID_ConfigGUI) {
            ConfigGUI := GuiFromHwnd(GuiID_ConfigGUI)
            if (ConfigGUI) {
                ; 定义所有规则类别
                RuleCategories := ["general", "web", "miniprogram", "plugin", "android", "ios", "python", "backend"]
                
                for Index, CategoryKey in RuleCategories {
                    try {
                        RulesEdit := ConfigGUI["CursorRulesContent" . CategoryKey]
                        if (RulesEdit) {
                            RulesContent := RulesEdit.Value
                            PlaceholderText := GetText("cursor_rules_content_placeholder")
                            ; 如果内容不是占位符且不为空，保存到配置文件
                            if (RulesContent != "" && RulesContent != PlaceholderText) {
                                ; IniWrite会自动处理换行符，直接保存即可
                                IniWrite(RulesContent, ConfigFile, "CursorRules", CategoryKey)
                            }
                        }
                    } catch as e {
                        ; 忽略单个规则保存失败，继续保存其他规则
                    }
                }
            }
        }
    } catch as e {
        ; 忽略保存规则时的错误，不影响其他配置的保存
    }
    
    ; 保存启用的搜索标签
    if (IsSet(VoiceSearchEnabledCategories) && IsObject(VoiceSearchEnabledCategories) && VoiceSearchEnabledCategories.Length > 0) {
        EnabledCategoriesStr := ""
        for Index, Category in VoiceSearchEnabledCategories {
            if (EnabledCategoriesStr != "") {
                EnabledCategoriesStr .= ","
            }
            EnabledCategoriesStr .= Category
        }
        IniWrite(EnabledCategoriesStr, ConfigFile, "Settings", "VoiceSearchEnabledCategories")
    } else {
        ; 如果为空，使用默认值
        IniWrite("ai,cli,academic,baidu,image,audio,video,book,price,medical,cloud", ConfigFile, "Settings", "VoiceSearchEnabledCategories")
    }
    
    ; 应用自启动设置
    SetAutoStart(AutoStart)
    
    IniWrite(FunctionPanelPos, ConfigFile, "Panel", "FunctionPanelPos")
    IniWrite(ConfigPanelPos, ConfigFile, "Panel", "ConfigPanelPos")
    IniWrite(ClipboardPanelPos, ConfigFile, "Panel", "ClipboardPanelPos")
    IniWrite(ConfigPanelScreenIndex, ConfigFile, "Advanced", "ConfigPanelScreenIndex")
    IniWrite(MsgBoxScreenIndex, ConfigFile, "Advanced", "MsgBoxScreenIndex")
    IniWrite(VoiceInputScreenIndex, ConfigFile, "Advanced", "VoiceInputScreenIndex")
    IniWrite(CursorPanelScreenIndex, ConfigFile, "Advanced", "CursorPanelScreenIndex")
    IniWrite(ClipboardPanelScreenIndex, ConfigFile, "Advanced", "ClipboardPanelScreenIndex")
    
    ; 保存自定义图标路径
    global CustomIconPath
    if (IsSet(CustomIconPath)) {
        if (CustomIconPath != "" && FileExist(CustomIconPath)) {
            IniWrite(CustomIconPath, ConfigFile, "Settings", "CustomIconPath")
        } else {
            IniWrite("", ConfigFile, "Settings", "CustomIconPath")
        }
    }
    
    ; 更新托盘图标（使用自定义图标）
    UpdateTrayIcon()
    
    ; 更新托盘菜单（语言可能已改变）
    UpdateTrayMenu()
    
    ; 更新面板显示的快捷键和按钮配置
    if (GuiID_CursorPanel != 0) {
        try {
            GuiID_CursorPanel.Destroy()
        }
        global GuiID_CursorPanel := 0
    }
    
    return true
}

; 显示保存成功提示（已移除，不再显示弹窗）
; ShowSaveSuccessTip(*) {
;     ; 创建临时GUI确保消息框置顶
;     TempGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
;     TempGui.Show("Hide")
;     MsgBox(GetText("config_saved"), GetText("tip"), "Iconi T1")
;     try TempGui.Destroy()
; }

; 显示导入成功提示（辅助函数）
ShowImportSuccessTip(*) {
    ; 创建临时GUI确保消息框置顶
    TempGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    TempGui.Show("Hide")
    MsgBox(GetText("import_success"), GetText("tip"), "Iconi")
    try TempGui.Destroy()
}

; 自动保存配置（延迟执行，避免频繁保存）
AutoSaveConfig(*) {
    ; 静默保存配置，不显示弹窗
    SaveConfig()
}

; 自动显示剪贴板管理面板（延迟执行，避免干扰复制操作）
AutoShowClipboardManager(*) {
    global GuiID_ClipboardManager
    ; 再次检查是否已打开（防止重复打开）
    if (GuiID_ClipboardManager = 0) {
        ShowClipboardManager()
        ; 切换到 CapsLock+C 标签
        global ClipboardCurrentTab
        if (ClipboardCurrentTab != "CapsLockC") {
            SwitchClipboardTab("CapsLockC")
        }
    }
}

; 保存配置并关闭
SaveConfigAndClose(*) {
    global GuiID_ConfigGUI
    
    if (SaveConfig()) {
        ; 关闭配置面板（不显示成功提示）
        CloseConfigGUI()
    }
}

; ===================== 清理函数 =====================
CleanUp() {
    global GuiID_CursorPanel, CapsLockHoldTimeSeconds, ConfigFile, GuiID_ConfigGUI, CapsLockHoldTimeEdit
    
    ; 【修复】在退出前保存CapsLock长按时间到配置文件
    try {
        ; 如果配置面板还打开着，优先从编辑框读取最新值
        if (GuiID_ConfigGUI != 0 && CapsLockHoldTimeEdit) {
            EditValue := CapsLockHoldTimeEdit.Value
            if (EditValue != "") {
                ; 尝试转换为浮点数（更健壮的方式）
                try {
                    NewHoldTime := Float(EditValue)
                    ; 验证值在合理范围内（0.1秒到5秒）
                    if (NewHoldTime >= 0.1 && NewHoldTime <= 5.0) {
                        CapsLockHoldTimeSeconds := NewHoldTime
                    } else {
                        ; 如果值超出范围，修正
                        if (NewHoldTime < 0.1) {
                            CapsLockHoldTimeSeconds := 0.1
                        } else if (NewHoldTime > 5.0) {
                            CapsLockHoldTimeSeconds := 5.0
                        }
                    }
                } catch as err {
                    ; 转换失败，保持当前值
                }
            }
        }
        
        ; 保存到配置文件（使用字符串格式确保精度）
        if (IsSet(CapsLockHoldTimeSeconds) && CapsLockHoldTimeSeconds != "") {
            IniWrite(String(CapsLockHoldTimeSeconds), ConfigFile, "Settings", "CapsLockHoldTimeSeconds")
        }
    } catch as err {
        ; 忽略保存错误
    }
    
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
    global CapsLock2, ClipboardHistory_CapsLockC, CapsLockCopyInProgress, CapsLockCopyEndTime
    global CapsLock, HotkeyC
    
    ; 诊断信息：确认函数被调用
    ; TrayTip("调试：CapsLockCopy() 函数被调用`n配置的快捷键: " . HotkeyC, "函数调用", "Iconi 2")
    
    ; 【关键修复】如果 CapsLockCopyInProgress 为 true，说明是在标签切换期间或其他阻止复制的场景，不执行复制
    ; 这样可以防止点击 CapsLock+C 标签时触发复制操作
    if (CapsLockCopyInProgress) {
        ; 【关键修复】如果 CapsLockCopyEndTime 被设置为未来时间，说明是在标签切换期间，不执行复制
        ; 优先检查这个，因为这是最明确的阻止信号
        if (CapsLockCopyEndTime > A_TickCount) {
            ; 在标签切换期间，直接返回，不执行任何复制操作
            return
        }
        ; 【关键修复】如果 CapsLock 为 false，说明是在标签切换期间，不执行复制操作
        if (!CapsLock) {
            ; 在标签切换期间，直接返回，不执行任何复制操作
            return
        }
    }
    
    ; 【关键修复】额外检查：如果 CapsLockCopyEndTime 被设置为未来时间（即使 CapsLockCopyInProgress 为 false），也不执行复制
    ; 这是双重保险，防止在标签切换期间触发复制
    if (CapsLockCopyEndTime > A_TickCount) {
        return
    }
    
    ; 【关键修复】额外检查：如果剪贴板管理面板已打开，且是标签点击期间，不执行复制
    ; 这个检查是为了防止在点击标签时，CapsLock 键还处于按下状态导致的意外触发
    global GuiID_ClipboardManager
    if (GuiID_ClipboardManager != 0 && CapsLockCopyInProgress && CapsLockCopyEndTime > A_TickCount) {
        ; 在标签点击期间且剪贴板管理面板打开时，不执行复制操作
        return
    }
    
    CapsLock2 := false  ; 清除标记，表示使用了功能
    ; 确保 CapsLock 变量在复制过程中保持为 true
    CapsLock := true
    
    ; 确保 ClipboardHistory_CapsLockC 已初始化（使用全局变量引用）
    if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
        global ClipboardHistory_CapsLockC := []
    }
    
    ; 标记 CapsLock+C 正在进行中，避免 OnClipboardChange 重复记录
    CapsLockCopyInProgress := true
    CapsLockCopyEndTime := 0  ; 重置结束时间
    
    ; 保存当前剪贴板内容
    OldClipboard := A_Clipboard
    
    ; 立即执行复制操作，使用 ClipWait 确保稳定性
    ; 清空剪贴板以便检测复制操作是否成功
    A_Clipboard := ""
    ; 发送 Ctrl+C 复制命令
    Send("^c")
    ; 短暂等待，确保复制命令被处理
    Sleep(50)
    
    ; 【环节1】等待复制完成，增加等待时间确保稳定性（从1.0秒增加到2.0秒）
    if !ClipWait(0.2) {
        ; 故障：ClipWait 超时 - 2秒内未检测到剪贴板变化
        ; 可能原因：1) 没有选中文本 2) 应用程序响应慢 3) 剪贴板被占用
        A_Clipboard := OldClipboard
        CapsLockCopyEndTime := A_TickCount
        SetTimer(ClearCapsLockCopyFlag, -1500)
        TrayTip("【故障】复制超时：2秒内未检测到剪贴板变化`n可能原因：未选中文本、应用响应慢或剪贴板被占用", GetText("tip"), "Iconx 3")
        return
    }
    
    ; 【环节2】额外等待，确保剪贴板内容完全准备好
    Sleep(150)
    
    ; 【环节3】获取新内容
    try {
        NewContent := A_Clipboard
    } catch as e {
        ; 故障：获取剪贴板内容异常
        ; 可能原因：剪贴板格式不支持或剪贴板被其他程序占用
        A_Clipboard := OldClipboard
        CapsLockCopyEndTime := A_TickCount
        SetTimer(ClearCapsLockCopyFlag, -1500)
        TrayTip("【故障】获取剪贴板内容失败`n错误：" . e.Message . "`n可能原因：剪贴板格式不支持或被占用", GetText("tip"), "Iconx 3")
        return
    }
    
    ; 【环节4】检查内容是否有效（不为空且长度大于0）
    if (NewContent != "" && StrLen(NewContent) > 0) {
        ; 【完全隔离】恢复系统剪贴板到原始内容，不改变系统剪贴板
        A_Clipboard := OldClipboard

        TrimmedContent := Trim(NewContent, " `t`r`n")
        ; 无论 Hub 触发模式偏好（Caps / 双击 Ctrl+C），CapsLock+C 成功复制后都应同步草稿本 Hub
        if (TrimmedContent != "") {
            try {
                SelectionSense_SyncHubFromUserCopyChannel(TrimmedContent, true)
            } catch as HubOpenErr {
                TrayTip("HubCapsule 同步失败`n" . HubOpenErr.Message, GetText("tip"), "Iconx 2")
            }
        }
        
        ; 【升级采集与分拣逻辑】调用智能分拣流程
        try {
            ; 【强制引用】明确声明全局数据库对象
            global ClipboardDB
            
            ; 【数据库检查】如果数据库不存在或未初始化，先初始化
            if (!ClipboardDB || ClipboardDB = 0) {
                InitClipboardDB()
                ; 再次检查
                if (!ClipboardDB || ClipboardDB = 0) {
                    TrayTip("【故障】数据库初始化失败`n无法保存数据", GetText("tip"), "Iconx 3")
                    CapsLockCopyEndTime := A_TickCount
                    SetTimer(ClearCapsLockCopyFlag, -1500)
                    return
                }
            }
            
            ; 【环境捕获】获取 SourceApp, SourceTitle, SourcePath
            EnvInfo := CaptureEnvironmentInfo()
            SourceApp := EnvInfo["SourceApp"]
            SourceTitle := EnvInfo["SourceTitle"]
            SourcePath := EnvInfo["SourcePath"]
            
            ; 【智能分类】对选中的文本进行正则判定（Link, Email, Code, Text）
            Classification := ClassifyClipboardContent(NewContent)
            DataType := Classification["DataType"]
            CharCount := Classification["CharCount"]
            WordCount := Classification["WordCount"]
            
            ; 【数据统计】计算 CharCount 和 WordCount（已在 ClassifyClipboardContent 中完成）
            
            ; 【物理入库】调用 SaveToDB 函数，它会自动处理排重检查
            ; SaveToDB 内部会查询末位记录，如果内容重复则跳过
            ; 使用 Trim 处理内容，确保数据一致性
            global ClipboardListView, GuiID_ClipboardManager, CapsLockCCount, CapsLockCItems, ClipboardFTS5DB
            ; 调用 SaveToDB（11字段架构，废弃 SessionID 模式）
            SaveToDB(TrimmedContent, DataType, SourceApp, SourceTitle, SourcePath, CharCount, WordCount)
            
            ; 【同步到 FTS5 数据库】确保 ClipboardHistoryPanel 和剪贴板管理面板都能显示
            ; 参考 ClipboardHistoryPanel.ahk，使用 ClipboardFTS5DB 存储数据
            ; 【关键修改】CapsLock+C 的数据使用 "Stack" 作为 DataType，便于单独归类
            if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
                try {
                    SaveToClipboardFTS5(TrimmedContent, SourceApp, "Stack")
                } catch as err {
                    ; 忽略错误，不影响主流程
                }
            }
            
            ; 【存储到 CapsLock+C 数组】将内容添加到当前阶段的数组
            CapsLockCItems.Push(TrimmedContent)

            ; 【实时计数】鼠标旁 ToolTip：已复制 N 条（与 HubCapsule 预览并存）
            CapsLockCCount++
            ShowCapsLockCCountTooltip()

            ; 【同步UI刷新】数据存入数据库后，立即刷新列表（如果分类面板打开着）
            ; 确保数据即时出现在"全部"和"代码"标签下
            if (GuiID_ClipboardManager != 0) {
                ; 如果剪贴板管理面板已打开，立即刷新列表
                SetTimer(RefreshClipboardListDelayed, -50)  ; 延迟50ms刷新，确保数据库写入完成
            }
            
            ; 【同步剪贴板历史面板】如果剪贴板历史面板已打开，自动切换到 CapsLock+C 标签
            global HistoryIsVisible, HistorySelectedTag, HistoryTagButtons, HistorySearchEdit
            if (IsSet(HistoryIsVisible) && HistoryIsVisible) {
                ; 自动切换到 CapsLock+C 标签
                HistorySelectedTag := "CapsLockC"
                ; 更新标签按钮样式
                if (IsSet(HistoryTagButtons) && HistoryTagButtons.Has("CapsLockC")) {
                    ; 调用 UpdateHistoryTagButtons 函数（在 ClipboardHistoryPanel.ahk 中定义）
                    try {
                        UpdateHistoryTagButtons()
                    } catch {
                        ; 如果函数不存在，忽略错误
                    }
                }
                ; 刷新数据（只显示 CapsLock+C 的数据）
                keyword := ""
                if (IsSet(HistorySearchEdit) && HistorySearchEdit) {
                    keyword := Trim(HistorySearchEdit.Value)
                }
                HistoryCurrentLimit := 100
                try {
                    RefreshHistoryData(keyword, 0, HistoryCurrentLimit)
                } catch {
                    ; 如果函数不存在，忽略错误
                }
            }
            
            ; CapsLock+C：默认不再强行弹出「剪贴板管理」面板，避免打断 HubCapsule 的选中/堆叠流程
            ; 若用户已经打开剪贴板管理，则仍然刷新/切换到 CapsLockC 标签（保持兼容）
            if (GuiID_ClipboardManager != 0) {
                if (ClipboardCurrentTab != "CapsLockC") {
                    SwitchClipboardTab("CapsLockC")
                } else {
                    SetTimer(RefreshClipboardListDelayed, -100)
                }
            }

        } catch as e {
            ; 故障：处理失败
            A_Clipboard := OldClipboard
            TrayTip("【故障】处理失败`n错误：" . e.Message, GetText("tip"), "Iconx 3")
            CapsLockCopyEndTime := A_TickCount
            SetTimer(ClearCapsLockCopyFlag, -1500)
            return
        }
        
    } else {
        ; 【警告】内容为空，恢复旧剪贴板
        A_Clipboard := OldClipboard
        TrayTip("【警告】复制的内容为空`n请先选中要复制的文本", GetText("tip"), "Iconi 2")
    }
    
    ; 记录结束时间，然后延迟清除标记，确保 OnClipboardChange 不会触发
    ; 无论是否成功添加内容，都要设置结束时间
    CapsLockCopyEndTime := A_TickCount
    SetTimer(ClearCapsLockCopyFlag, -1500)  ; 延迟1.5秒，确保 OnClipboardChange 不会触发
}

; 清除 CapsLock+C 标记的辅助函数
ClearCapsLockCopyFlag(*) {
    global CapsLockCopyInProgress
    CapsLockCopyInProgress := false
}

; ===================== CapsLock+C 计数提示 =====================
; 显示 CapsLock+C 复制计数 Tooltip
ShowCapsLockCCountTooltip() {
    global CapsLockCCount, CapsLockCCountTooltip
    
    ; 获取鼠标位置
    MouseGetPos(&MouseX, &MouseY)
    
    ; 如果已有 Tooltip，先隐藏
    if (CapsLockCCountTooltip != 0) {
        ToolTip(, , , CapsLockCCountTooltip)
    }
    
    ; 显示新的 Tooltip
    ; 注意：ToolTip 的第4个参数必须是数字（ToolTip ID），不能是字符串
    TooltipText := "已复制 " . CapsLockCCount . " 条"
    ; 使用固定的 ToolTip ID（1），用于 CapsLock+C 计数提示
    CapsLockCCountTooltip := 1
    ToolTip(TooltipText, MouseX + 20, MouseY + 20, CapsLockCCountTooltip)
    
    ; 3秒后自动隐藏
    SetTimer(() => HideCapsLockCCountTooltip(), -3000)
}

; 隐藏 CapsLock+C 计数 Tooltip
HideCapsLockCCountTooltip() {
    global CapsLockCCountTooltip
    
    if (CapsLockCCountTooltip != 0) {
        ToolTip(, , , CapsLockCCountTooltip)
        CapsLockCCountTooltip := 0
    }
}

; 恢复 CapsLock 状态的辅助函数（用于标签切换）
RestoreCapsLockState(*) {
    global CapsLock, CapsLock2, OldCapsLockForTab, OldCapsLock2ForTab
    if (IsSet(OldCapsLockForTab)) {
        CapsLock := OldCapsLockForTab
    }
    if (IsSet(OldCapsLock2ForTab)) {
        CapsLock2 := OldCapsLock2ForTab
    }
}

; 恢复 CapsLock+C 复制标记的辅助函数（用于标签切换）
RestoreCapsLockCopyFlag(*) {
    global CapsLockCopyInProgress, OldCapsLockCopyInProgress
    if (IsSet(OldCapsLockCopyInProgress)) {
        CapsLockCopyInProgress := OldCapsLockCopyInProgress
    } else {
        CapsLockCopyInProgress := false
    }
}

; 异步处理 (已废弃，改用同步 ClipWait)
ProcessCopyResult(OldClipboard) {
    return
}

; ===================== 合并粘贴功能 =====================
; CapsLock+V: 将当前阶段的所有内容合并后粘贴到 Cursor 输入框
CapsLockPaste() {
    try {
        global CapsLock2, g_HubCapsule_SelectedText, CapsLockCCount, CapsLockCItems
        CapsLock2 := false

        t := ""
        try t := Trim(String(g_HubCapsule_SelectedText), " `t`r`n")

        ; 若 HubCapsule 已选中某条卡片：直接粘贴到当前输入焦点（不强制切 Cursor）
        if (t != "") {
            SendText(t)
            ; 粘贴成功后，重置 CapsLock+C 阶段计数与缓存，开始新一轮
            CapsLockCCount := 0
            CapsLockCItems := []
            HideCapsLockCCountTooltip()
            return
        }

        ; 否则：弹出 HubCapsule 让用户点选卡片，再按一次 CapsLock+V 粘贴
        try {
            if FuncExists("SelectionSense_OpenHubCapsuleFromToolbar") {
                SelectionSense_OpenHubCapsuleFromToolbar(false, "")
                TrayTip("在 HubCapsule 点选要粘贴的卡片，再按 CapsLock+V", GetText("tip"), "Iconi 1")
                return
            }
        } catch as _e {
        }

        TrayTip("【警告】HubCapsule 未就绪`n请先用 CapsLock+C 复制内容", GetText("tip"), "Iconi 2")
    } catch as e {
        MsgBox(GetText("paste_failed") . ": " . e.Message)
    }
}


; ===================== 截图助手（ScreenshotEditorPlugin 类模块）=====================
#Include modules\ScreenshotEditorPlugin.ahk

ShowScreenshotEditor(DebugGui := 0) {
    ScreenshotEditorPlugin.ShowScreenshotEditor(DebugGui)
}
CloseScreenshotEditor(*) {
    ScreenshotEditorPlugin.CloseScreenshotEditor()
}
CloseAllScreenshotWindows(*) {
    ScreenshotEditorPlugin.CloseAllScreenshotWindows()
}
IsScreenshotEditorActive() {
    return ScreenshotEditorPlugin.IsScreenshotEditorActive()
}
HandleScreenshotEditorHotkey(ActionType) {
    return ScreenshotEditorPlugin.HandleScreenshotEditorHotkey(ActionType)
}
IsScreenshotEditorZoomHotkeyActive() {
    return ScreenshotEditorPlugin_IsZoomHotkeyActive()
}
ToggleScreenshotEditorAlwaysOnTop(*) {
    ScreenshotEditorPlugin.ToggleScreenshotEditorAlwaysOnTop()
}
ScreenshotEditorSendToAI(*) {
    ScreenshotEditorPlugin.ScreenshotEditorSendToAI()
}
ScreenshotEditorSearchText(*) {
    ScreenshotEditorPlugin.ScreenshotEditorSearchText()
}
ExecuteScreenshotOCR(*) {
    ScreenshotEditorPlugin.ExecuteScreenshotOCR()
}
PasteScreenshotAsText(*) {
    ScreenshotEditorPlugin.PasteScreenshotAsText()
}
SaveScreenshotToFile(closeAfter := true) {
    ScreenshotEditorPlugin.SaveScreenshotToFile(closeAfter)
}
CopyScreenshotToClipboard(closeAfter := true) {
    ScreenshotEditorPlugin.CopyScreenshotToClipboard(closeAfter)
}
UpdateScreenshotEditorPreview(*) {
    ScreenshotEditorPlugin.UpdateScreenshotEditorPreview()
}
SyncScreenshotToolbarPosition(*) {
    ScreenshotEditorPlugin.SyncScreenshotToolbarPosition()
}
OnScreenshotEditorContextMenu(Ctrl, Info := 0, *) {
    ScreenshotEditorPlugin.OnScreenshotEditorContextMenu(Ctrl, Info)
}


; ===================== 截图业务流程（智能菜单 / 区域截图 / 悬浮按钮）=====================
#Include modules\ScreenshotWorkflow.ahk

#Include modules\CapsLockDynamicHotkey.ahk


; ===================== 面板快捷键 =====================
; 当 CapsLock 按下时，响应快捷键（采用 CapsLock+ 方案）
; 注意：在 AutoHotkey v2 中，需要使用函数来检查变量
#HotIf SearchCenter_ShouldCaptureGlobalHotkeys()

Esc:: {
    global IsCountdownActive, GDHO_VISIBLE, NativeDropSessionActive, g_SCWV_WaitingUiFinishedReveal
    try NativeDropDiag_Log("route esc key=Esc path=search_center_visible")
    if FuncExists("GDHO_DismissLauncherOnEsc") {
        try {
            if GDHO_DismissLauncherOnEsc("esc_search_center")
                return
        } catch {
        }
    }
    if (IsCountdownActive) {
        try NativeDropDiag_Log("route esc key=Esc path=countdown_cancel")
        CancelCountdown()
        return
    }
    try {
        if FuncExists("GDHO_IsTextHoleUserPanelActive") {
            try {
                if GDHO_IsTextHoleUserPanelActive() && FuncExists("GDHO_DismissTextHolePanel") {
                    try NativeDropDiag_Log("route esc key=Esc path=text_hole_panel_dismiss")
                    GDHO_DismissTextHolePanel("esc_global")
                    return
                }
            } catch {
            }
        }
        if (GDHO_VISIBLE || NativeDropSessionActive || g_SCWV_WaitingUiFinishedReveal) {
            try NativeDropDiag_Log("route esc key=Esc path=hard_force_close")
            SearchCenterUnifiedClose("esc_black_hole", true, true)
            return
        }
        try NativeDropDiag_Log("route esc key=Esc path=unified_close visible=" . (SCWV_IsVisible() ? "1" : "0"))
        if (SearchCenterUnifiedClose("esc", false, true))
            return
    } catch {
    }
    Send("{Esc}")
}

$^+q:: {
    try ReloadScriptFromPopupMenu()
    catch {
    }
}

RestoreActivationRuntimeAfterConfigClose(*) {
    global g_ConfigOpenEntryMode, TrayMenuCustomFailStreak, TrayMenuSuppressNativeFallbackUntil
    try {
        mode := ""
        try mode := NormalizeAppearanceActivationMode(g_ConfigOpenEntryMode)
        catch
            mode := ""
        if (mode != "hole" && mode != "toolbar" && mode != "tray")
            mode := NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar")
        ApplyActivationRuntimeAsync(mode)
        try ApplyAppearanceActivationMode()
        catch {
        }
        TrayMenuCustomFailStreak := 0
        TrayMenuSuppressNativeFallbackUntil := A_TickCount + 1800
        try UpdateTrayMenu()
    } catch {
    }
    g_ConfigOpenEntryMode := ""
}

#HotIf CapsLockChordHotIf()

; ESC 关闭面板
Esc:: {
    if FuncExists("CapsLockChordInputBlocked") && CapsLockChordInputBlocked()
        return
    ; 搜索中心优先：避免 WebView 激活态瞬时判定失败时，Esc 误落到全局动态热键（如关闭工具栏）
    global GDHO_VISIBLE, NativeDropSessionActive, g_SCWV_WaitingUiFinishedReveal
    if FuncExists("GDHO_DismissLauncherOnEsc") {
        try {
            if GDHO_DismissLauncherOnEsc("esc_caps")
                return
        } catch {
        }
    }
    try {
        if FuncExists("GDHO_IsTextHoleUserPanelActive") {
            try {
                if GDHO_IsTextHoleUserPanelActive() && FuncExists("GDHO_DismissTextHolePanel") {
                    try NativeDropDiag_Log("route esc key=Esc path=text_hole_panel_dismiss_caps")
                    GDHO_DismissTextHolePanel("esc_global")
                    return
                }
            } catch {
            }
        }
        if (GDHO_VISIBLE || NativeDropSessionActive || g_SCWV_WaitingUiFinishedReveal) {
            try NativeDropDiag_Log("route esc key=Esc path=hard_force_close_caps")
            SearchCenterUnifiedClose("esc_black_hole_caps", true, true)
            return
        }
        try NativeDropDiag_Log("route esc key=Esc path=unified_close_caps visible=" . (SCWV_IsVisible() ? "1" : "0"))
        if (SearchCenterUnifiedClose("esc_caps", false, true))
            return
    } catch {
    }
    if (VirtualKeyboard_HandleKey("Esc"))
        return
    if (!HandleDynamicHotkey("Esc", "ESC")) {
        ; 如果不匹配，发送原始按键
        Send("{Esc}")
    }
}

; C 键连续复制（立即响应，不等待面板）；$ 强制钩子，避免 WebView2 焦点下漏触发
$c:: {
    if (SearchCenter_HandleCapsChordKey("c"))
        return
    ; 【关键修复】在剪贴板管理面板打开时，检查是否是标签点击期间
    ; 如果是标签点击期间，不执行复制操作，避免点击标签时触发复制
    global GuiID_ClipboardManager, CapsLockCopyInProgress, CapsLockCopyEndTime
    
    ; 如果剪贴板管理面板已打开，检查是否是标签切换期间
    if (GuiID_ClipboardManager != 0) {
        ; 检查是否是标签点击期间（通过 CapsLockCopyInProgress 和 CapsLockCopyEndTime 判断）
        if (CapsLockCopyInProgress && CapsLockCopyEndTime > A_TickCount) {
            ; 在标签点击期间，不执行复制操作，直接返回
            return
        }
    }
    
    ; 确保 CapsLock 变量被设置（防止在释放时被清除）
    global CapsLock
    if (!CapsLock) {
        CapsLock := true
    }

    if (VirtualKeyboard_HandleKey("c"))
        return
    if (HandleDynamicHotkey("c", "C"))
        VK_NoteLastChFromCapsLockKey("c")
    else
        return
}

; V 键：Shift+V 合并粘贴（Hub）；否则一律唤醒剪贴板时间线（不走 HotkeyV / VK 绑定）
$v:: {
    if GetKeyState("Shift", "P") {
        CapsLock2 := false
        RestoreCapsLockAfterChord()
        CapsLockPaste()
        VK_NoteLastChFromCapsLockKey("v")
        return
    }
    CapsLock2 := false
    RestoreCapsLockAfterChord()
    if (SearchCenter_ShouldUseWebView())
        SurfaceIntent_OpenClipboardUnified("", "clipboard_hotkey")
    else
        ShowSearchCenter()
    VK_NoteLastChFromCapsLockKey("v")
}

; X 键打开剪贴板管理面板（新的 FTS5 剪贴板管理器）
$x:: {
    if (SearchCenter_HandleCapsChordKey("x"))
        return
    if (VirtualKeyboard_HandleKey("x"))
        return
    if (HandleDynamicHotkey("x", "X"))
        VK_NoteLastChFromCapsLockKey("x")
    else
        return
}

; E 键执行解释
$e:: {
    if (SearchCenter_HandleCapsChordKey("e"))
        return
    if (VirtualKeyboard_HandleKey("e"))
        return
    if (HandleDynamicHotkey("e", "E"))
        VK_NoteLastChFromCapsLockKey("e")
    else
        return
}

; R 键执行重构
$r:: {
    if (SearchCenter_HandleCapsChordKey("r"))
        return
    if (VirtualKeyboard_HandleKey("r"))
        return
    if (HandleDynamicHotkey("r", "R"))
        VK_NoteLastChFromCapsLockKey("r")
    else
        return
}

; O 键执行优化
o:: {
    if (VirtualKeyboard_HandleKey("o"))
        return
    if (HandleDynamicHotkey("o", "O"))
        VK_NoteLastChFromCapsLockKey("o")
    else
        return
}

; Q 键打开配置面板
$q:: {
    if (SearchCenter_HandleCapsChordKey("q"))
        return
    if (VirtualKeyboard_HandleKey("q"))
        return
    if (HandleDynamicHotkey("q", "Q"))
        VK_NoteLastChFromCapsLockKey("q")
    else
        return
}

; Z 键语音输入（切换模式）
$z:: {
    global IsCountdownActive
    ; 倒计时/等待阶段禁止触发语音输入类动态命令，避免误激活。
    if (IsCountdownActive) {
        ExecuteCountdownAction()
        return
    }
    if (SearchCenter_HandleCapsChordKey("z"))
        return
    if (VirtualKeyboard_HandleKey("z"))
        return
    if (HandleDynamicHotkey("z", "Z"))
        VK_NoteLastChFromCapsLockKey("z")
    else
        return
}

; T 键执行截图并弹出智能菜单
t:: {
    if (VirtualKeyboard_HandleKey("t"))
        return
    if (HandleDynamicHotkey("t", "T"))
        VK_NoteLastChFromCapsLockKey("t")
    else
        return
}

; F 键：激活搜索中心或执行区域内操作
f:: {
    global IsCountdownActive, CapsLock2, g_SCWV_WaitingUiFinishedReveal, g_SCWV_CreateInFlight
    if (VirtualKeyboard_HandleKey("f"))
        return
    try {
        searchVisible := false
        try searchVisible := SCWV_IsVisible()
        catch {
            searchVisible := false
        }
        try SCWV_Log("caps_f_state", "search_active=" . (IsSearchCenterActive() ? "1" : "0") . " search_visible=" . (searchVisible ? "1" : "0") . " waiting=" . (g_SCWV_WaitingUiFinishedReveal ? "1" : "0") . " create_inflight=" . (g_SCWV_CreateInFlight ? "1" : "0") . " phase=" . (IsSet(g_SCWV_LifecyclePhase) ? g_SCWV_LifecyclePhase : "") . " countdown=" . (IsCountdownActive ? "1" : "0") . " caps=" . (GetCapsLockState() ? "1" : "0"))
        catch {
        }
    }
    if (IsSearchCenterActive() && SCWV_IsRevealedToUser() && SearchCenter_HandleCapsChordKey("f")) {
        VK_NoteLastChFromCapsLockKey("f")
        return
    }
    ; 标记已使用组合键，避免 CapsLock 释放时走“单击切换大小写”分支
    CapsLock2 := false
    RestoreCapsLockAfterChord()
    ; 如果倒计时正在进行，按下 F 立即加速执行（发射内容）
    if (IsCountdownActive) {
        ExecuteCountdownAction()
        VK_NoteLastChFromCapsLockKey("f")
        return
    }
    
    ; 如果 SearchCenter 已真正显示且激活，执行区域内操作逻辑
    if (IsSearchCenterActive() && SCWV_IsRevealedToUser()) {
        HandleSearchCenterF()
        VK_NoteLastChFromCapsLockKey("f")
    } else {
        ; 否则激活搜索中心窗口（综合搜索意图）
        if (SearchCenter_ShouldUseWebView())
            SurfaceIntent_OpenSearch("", "search_hotkey")
        else
            ShowSearchCenter()
        VK_NoteLastChFromCapsLockKey("f")
    }
}

; G 键激活语音搜索面板
g:: {
    global CapsLock2
    if (VirtualKeyboard_HandleKey("g"))
        return
    ; 与 CapsLock+F 一致：明确标记组合键已消费，避免释放时误切换大小写状态
    CapsLock2 := false
    RestoreCapsLockAfterChord()
    ; CapsLock+G 激活原来的语音搜索面板
    StartVoiceSearch()
    VK_NoteLastChFromCapsLockKey("g")
}

; B 键：面板显示且批量键为 B 时走 BatchOperation；面板显示且非批量键则透传 b；面板未显示时打开 Prompt 采集窗
b:: {
    global CapsLock2
    if (VirtualKeyboard_HandleKey("b"))
        return
    RestoreCapsLockAfterChord()
    PromptQuickPad_HandleCapsLockB()
    VK_NoteLastChFromCapsLockKey("b")
}

#HotIf  ; 结束 GetCapsLockState() 作用域，为 SearchCenter 专用热键让路

; 命令面板可见时仍允许 CapsLock+F 抢占打开搜索中心（不经 InputBlocked，否则 CP 前台时 #HotIf 恒为假）
#HotIf CapsLockChordPhysDown() && FuncExists("CommandPalette_IsVisible") && CommandPalette_IsVisible()
$f:: {
    global CapsLock2, IsCountdownActive
    CapsLock2 := false
    if FuncExists("CapsLock_RestoreForUiTypingOpen")
        CapsLock_RestoreForUiTypingOpen()
    else {
        RestoreCapsLockAfterChord()
        if FuncExists("CapsLock_ScheduleNormalizeAfterChord")
            CapsLock_ScheduleNormalizeAfterChord()
    }
    if (IsCountdownActive) {
        ExecuteCountdownAction()
        try VK_NoteLastChFromCapsLockKey("f")
        catch {
        }
        return
    }
    if (SearchCenter_ShouldUseWebView()) {
        try {
            pid := DllCall("GetCurrentProcessId", "UInt")
            DllCall("AllowSetForegroundWindow", "UInt", pid)
        } catch {
        }
        SurfaceIntent_OpenSearch("", "search_hotkey")
        if FuncExists("SCWV_StartHotkeyForegroundPump")
            try SCWV_StartHotkeyForegroundPump()
            catch {
            }
    } else
        ShowSearchCenter()
    try VK_NoteLastChFromCapsLockKey("f")
    catch {
    }
}
#HotIf

; ===================== SearchCenter 窗口热键（优先级最高）=====================
; 【重要】必须在全局 CapsLock 热键之前定义，确保优先级
; 【作用域】Legacy GUI 才托管 Enter/方向键；WebView 由页面收键
#HotIf SearchCenter_ShouldCaptureLegacyListHotkeys()

    ; Enter 键：根据焦点区域执行不同操作，或加速倒计时
Enter:: {
    global IsCountdownActive
    global GuiID_SearchCenter, SearchCenterSearchEdit
    if (IsCountdownActive) {
        ExecuteCountdownAction()
        return
    }
    ; WebView 搜索中心：撰写区 Enter/Ctrl+Enter 由页面处理，避免抢键导致 TrayTip/批量搜索
    try {
        if (SearchCenter_ShouldUseWebView() && SCWV_IsVisible())
            return
    } catch {
    }
    global SearchCenterActiveArea, SearchCenterResultLV, SearchCenterSearchResults, SearchCenterSearchEdit
    
    ; CLI：焦点在顶部输入框时一律发送（避免 ActiveArea 仍为 listview 等导致 Enter 未触发 CLI）
    if (SearchCenterIsCLICategory() && SearchCenterSearchEdit != 0 && GuiID_SearchCenter != 0) {
        try {
            Fh := ControlGetFocus("ahk_id " . GuiID_SearchCenter.Hwnd)
            if (Fh && Fh = SearchCenterSearchEdit.Hwnd) {
                ExecuteSearchCenterCLICommand()
                return
            }
        } catch {
        }
    }
    
    if (SearchCenterIsCLICategory() && (SearchCenterActiveArea = "input" || SearchCenterActiveArea = "category")) {
        ExecuteSearchCenterCLICommand()
        return
    }
    
    if (SearchCenterActiveArea = "listview") {
        ; 焦点在ListView：启动倒计时
        if (!SearchCenterResultLV || SearchCenterResultLV = 0) {
            return
        }
        
        SelectedRow := SearchCenterResultLV.GetNext()
        if (SelectedRow = 0) {
            ; 如果没有选中项，选中第一项
            if (SearchCenterResultLV.GetCount() > 0) {
                SearchCenterResultLV.Modify(1, "Select Focus")
                SelectedRow := 1
            } else {
                return
            }
        }
        
        ; 获取选中项的内容并启动倒计时
        if (SelectedRow > 0 && SelectedRow <= SearchCenterSearchResults.Length) {
            Item := GetSearchCenterResultItemByRow(SelectedRow)
            if (!IsObject(Item)) {
                return
            }
            Content := Item.HasProp("Content") ? Item.Content : Item.Title
            
            ; 启动倒计时前的准备（不显示提示，直接进入倒计时准备粘贴）
            SearchCenterListViewLaunchHandler(Content, Item.Title)
        }
    } else {
        ; 【关键修复】焦点在输入框或分类栏：如果输入框有内容，执行批量搜索跳转到已勾选的搜索引擎；否则执行批量搜索
        if (SearchCenterActiveArea = "input" && IsSet(SearchCenterSearchEdit) && SearchCenterSearchEdit && SearchCenterSearchEdit.Value != "") {
            ; 输入框有内容，执行批量搜索跳转到已勾选的搜索引擎
            ExecuteSearchCenterBatchSearch()
        } else {
            ; 焦点在分类栏或输入框为空：执行批量搜索
            ExecuteSearchCenterBatchSearch()
        }
    }
}

; 方向键映射（在 searchcenter 中遵守三个区域的操作规范）
; 【三个区域】category（分类栏）、input（输入框）、listview（结果列表）
; 【行为规范】详见 HandleSearchCenterUp/Down/Left/Right 函数的注释
$Up::HandleSearchCenterUp()      ; ↑ 键：根据当前区域执行相应操作
$Down::HandleSearchCenterDown()  ; ↓ 键：根据当前区域执行相应操作
$Left::HandleSearchCenterLeft()   ; ← 键：根据当前区域执行相应操作
$Right::HandleSearchCenterRight() ; → 键：根据当前区域执行相应操作

; CapsLock + WASD 映射（完全复刻方向键功能）
; 【优先级】更具体的作用域（IsSearchCenterActive() && GetCapsLockState()）优先于全局作用域（GetCapsLockState()）
; 【功能】在 searchcenter 中，capslock+wsad 与方向键行为完全一致，遵守三个区域的操作规范
; 【三个区域】category（分类栏）、input（输入框）、listview（结果列表）
#HotIf SearchCenter_ShouldCaptureGlobalHotkeys() && CapsLockChordHotIf()
$q::SearchCenter_HandleCapsChordKey("q")
$w::SearchCenter_HandleCapsChordKey("w")
$e::SearchCenter_HandleCapsChordKey("e")
$r::SearchCenter_HandleCapsChordKey("r")
$a::SearchCenter_HandleCapsChordKey("a")
$s::SearchCenter_HandleCapsChordKey("s")
$d::SearchCenter_HandleCapsChordKey("d")
$z::SearchCenter_HandleCapsChordKey("z")
$x::SearchCenter_HandleCapsChordKey("x")
$c::SearchCenter_HandleCapsChordKey("c")
$v:: {
    if GetKeyState("Shift", "P") {
        CapsLock2 := false
        RestoreCapsLockAfterChord()
        CapsLockPaste()
        return
    }
    CapsLock2 := false
    RestoreCapsLockAfterChord()
    SurfaceIntent_OpenClipboardUnified("", "clipboard_hotkey")
}

; F 键：在倒计时期间加速执行
$f:: {
    global IsCountdownActive, CapsLock2
    if (SearchCenter_HandleCapsChordKey("f"))
        return
    CapsLock2 := false
    if (IsCountdownActive) {
        ExecuteCountdownAction()
    } else {
        HandleSearchCenterF()
    }
}

#HotIf  ; 结束 SearchCenter 作用域

CountdownHotkeyActive() {
    global IsCountdownActive
    try return !!IsCountdownActive
    catch {
        return false
    }
}

; ===================== 倒计时期间全局热键 =====================
; 【作用域】倒计时激活时全局生效（优先级最高）
#HotIf CountdownHotkeyActive()

; F 键：加速执行
f:: {
    ExecuteCountdownAction()
}

; Enter 键：加速执行
Enter:: {
    ExecuteCountdownAction()
}

; ESC 键：取消倒计时
Esc:: {
    CancelCountdown()
}

#HotIf  ; 结束倒计时作用域

; ===================== 全局 CapsLock 热键（优先级较低）=====================
; 【作用域】CapsLock 按下时全局生效（SearchCenter 除外，因为上面已经定义了更具体的热键）
#HotIf CapsLockChordHotIf()

; W 键映射为 Up（上方向键）- 全局生效（SearchCenter 中会被上面的专用热键覆盖）
$w:: {
    if FuncExists("CapsLockChordInputBlocked") && CapsLockChordInputBlocked()
        return
    if (SearchCenter_HandleCapsChordKey("w"))
        return
    global CapsLock2
    if (VirtualKeyboard_HandleKey("w"))
        return
    CapsLock2 := false
    RestoreCapsLockAfterChord()
    Send("{Up}")
    VK_NoteLastChFromCapsLockKey("w")
}

; S 键映射为 Down（下方向键）- 全局生效（SearchCenter 中会被上面的专用热键覆盖）
$s:: {
    if FuncExists("CapsLockChordInputBlocked") && CapsLockChordInputBlocked()
        return
    if (SearchCenter_HandleCapsChordKey("s"))
        return
    global CapsLock2
    if (VirtualKeyboard_HandleKey("s"))
        return
    CapsLock2 := false
    RestoreCapsLockAfterChord()
    Send("{Down}")
    VK_NoteLastChFromCapsLockKey("s")
}

; A 键映射为 Left（左方向键）- 全局生效（SearchCenter 中会被上面的专用热键覆盖）
$a:: {
    if FuncExists("CapsLockChordInputBlocked") && CapsLockChordInputBlocked()
        return
    if (SearchCenter_HandleCapsChordKey("a"))
        return
    global CapsLock2
    if (VirtualKeyboard_HandleKey("a"))
        return
    CapsLock2 := false
    RestoreCapsLockAfterChord()
    Send("{Left}")
    VK_NoteLastChFromCapsLockKey("a")
}

; D 键映射为 Right（右方向键）- 全局生效（SearchCenter 中会被上面的专用热键覆盖）
$d:: {
    if FuncExists("CapsLockChordInputBlocked") && CapsLockChordInputBlocked()
        return
    if (SearchCenter_HandleCapsChordKey("d"))
        return
    global CapsLock2
    if (VirtualKeyboard_HandleKey("d"))
        return
    CapsLock2 := false
    RestoreCapsLockAfterChord()
    Send("{Right}")
    VK_NoteLastChFromCapsLockKey("d")
}

; P 键区域截图
p:: {
    if (VirtualKeyboard_HandleKey("p"))
        return
    if (HandleDynamicHotkey("p", "P"))
        VK_NoteLastChFromCapsLockKey("p")
    else
        return
}

#HotIf

; ===================== SearchCenter 其他功能键 =====================

#HotIf  ; 结束 IsSearchCenterActive() && GetCapsLockState() 作用域

; Ctrl+Alt+T：强制恢复到悬浮工具栏模式（从悬浮球/托盘一键回到工具栏）
^!t:: {
    global AppearanceActivationMode, ConfigFile
    try AppearanceActivationMode := "toolbar"
    try IniWrite("toolbar", ConfigFile, "Appearance", "ActivationMode")
    try HideFloatingBubble()
    try SurfaceIntent_Open("floating_toolbar")
    try ApplyAppearanceActivationMode()
    try TrayTip("悬浮工具栏", "已恢复工具栏模式", "Iconi Mute")
}

; 中键保留给系统/浏览器原生行为（如后台开标签），不再绑定 MButton & Wheel*
; 若需模式切换请使用下方 Alt+滚轮 兜底热键。

; 兼容某些鼠标驱动对「MButton & Wheel」组合拦截：提供 Alt+滚轮 全局切换兜底
!WheelUp:: {
    try FloatingToolbar_SetActivationMode("toolbar")
    try FloatingToolbar_ForceRecoverVisible()
}

!WheelDown:: {
    try FloatingToolbar_SetActivationMode("bubble")
}

; 强制恢复悬浮工具栏到可见区域（紧急兜底）
^!y:: {
    global ConfigFile
    try AppearanceActivationMode := "toolbar"
    try IniWrite("toolbar", ConfigFile, "Appearance", "ActivationMode")
    try FloatingToolbar_ForceRecoverVisible()
}

; 仅强制显示工具栏（不改其它设置）
^!u:: {
    try FloatingToolbar_ForceRecoverVisible()
}

; 全局设置入口（不依赖当前激活模式）
^!q:: {
    try ShowConfigGUI_Safe()
}

; VK qa_* 命令等仍可调用的动作路由（不再依赖 Cursor Quick Actions 面板）
ExecuteQuickActionByType(Type) {
    global CapsLock2

    CapsLock2 := false
    try HideCursorPanel()

    switch Type {
        case "Config":
            ShowConfigGUI_Safe()
        case "Copy":
            CapsLockCopy()
        case "Paste":
            CapsLockPaste()
        case "Clipboard":
            SurfaceIntent_Open("clipboard_panel")
        case "Voice":
            StartVoiceInput()
        case "Split":
            SplitCode()
        case "Batch":
            BatchOperation()
        case "CommandPalette":
            ExecuteCursorShortcut(GetCursorActionShortcut("CommandPalette"))
        case "Terminal":
            ExecuteCursorShortcut(GetCursorActionShortcut("Terminal"))
        case "GlobalSearch":
            ExecuteCursorShortcut(GetCursorActionShortcut("GlobalSearch"))
        case "Explorer":
            ExecuteCursorShortcut(GetCursorActionShortcut("Explorer"))
        case "SourceControl":
            ExecuteCursorShortcut(GetCursorActionShortcut("SourceControl"))
        case "Extensions":
            ExecuteCursorShortcut(GetCursorActionShortcut("Extensions"))
        case "Browser":
            ExecuteCursorShortcut(GetCursorActionShortcut("Browser"))
        case "Settings":
            ExecuteCursorShortcut(GetCursorActionShortcut("Settings"))
        case "CursorSettings":
            ExecuteCursorShortcut(GetCursorActionShortcut("CursorSettings"))
    }
}

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
; 注：CapsLock+B 批量逻辑已合并到上方 #HotIf CapsLockChordHotIf() 的 b:: 中

; SetAutoStart → modules\ConfigManager.ahk（注册表 Run 写入 A_AhkPath + 主脚本）

; 搜索中心模块化：GlobalSearchEngine、OpenSearchGroupEngines/EncodeURIComponent、Legacy ListView GUI
#Include modules\GlobalSearchEngine.ahk
#Include modules\SearchCenterUrlHelpers.ahk
#Include modules\SearchCenterLegacyGui.ahk




; ===================== 语音模块（中枢 #Include VoiceInputModule）=====================
#Include modules\VoiceInputStateMachine.ahk
#Include modules\VoiceInputModule.ahk
#Include modules\VoiceInputEffects.ahk

; 对指定窗口尝试 IMM 中文模式 + 简体键盘布局（WebView 焦点常在子 HWND 上，需多候选）
ApplyChineseIMEConversionToHwnd(RootHwnd) {
    if (!RootHwnd)
        return
    fg := DllCall("user32\GetForegroundWindow", "Ptr")
    candidates := [RootHwnd]
    if (fg && fg != RootHwnd)
        candidates.Push(fg)
    hIMC := 0
    releaseHwnd := RootHwnd
    for _, hwndTry in candidates {
        hIMC := DllCall("imm32\ImmGetContext", "Ptr", hwndTry, "Ptr")
        if (hIMC) {
            releaseHwnd := hwndTry
            break
        }
    }
    if (hIMC) {
        DllCall("imm32\ImmGetConversionStatus", "Ptr", hIMC, "UInt*", &ConversionMode := 0, "UInt*", &SentenceMode := 0)
        ; IME_CMODE_NATIVE：中文输入；并清除 CHARCODE(0x20)，减少符号/编码类异常态
        ConversionMode := (ConversionMode | 0x0001) & ~0x0020
        DllCall("imm32\ImmSetConversionStatus", "Ptr", hIMC, "UInt", ConversionMode, "UInt", SentenceMode)
        DllCall("imm32\ImmReleaseContext", "Ptr", releaseHwnd, "Ptr", hIMC)
    }
    try {
        hKL := DllCall("user32\LoadKeyboardLayout", "Str", "00000804", "UInt", 0x00000001, "Ptr")
        if (hKL)
            PostMessage(0x0050, 0x0001, hKL, , , "ahk_id " . RootHwnd)
    } catch as err {
    }
}

; 切换到中文输入法（用于搜索中心窗口）
SwitchToChineseIMEForSearchCenter(*) {
    try {
        global GuiID_SearchCenter, SearchCenterSearchEdit
        ActiveHwnd := 0
        if (SearchCenter_ShouldUseWebView()) {
            try SCWV_FocusForIME()
            Sleep(100)
            if (IsObject(GuiID_SearchCenter) && GuiID_SearchCenter.HasProp("Hwnd"))
                ActiveHwnd := GuiID_SearchCenter.Hwnd
            if (!ActiveHwnd)
                ActiveHwnd := WinGetID("A")
        } else if (GuiID_SearchCenter && SearchCenterSearchEdit) {
            LegacyGuard_RequestFocus("Main.SearchCenter", "ahk_id " . GuiID_SearchCenter.Hwnd, 55, "search_center_hotkey")
            Sleep(50)
            SearchCenterSearchEdit.Focus()
            Sleep(50)
            ActiveHwnd := GuiID_SearchCenter.Hwnd
        } else {
            ActiveHwnd := WinGetID("A")
        }
        if (!ActiveHwnd)
            return
        ApplyChineseIMEConversionToHwnd(ActiveHwnd)
    } catch as err {
    }
}



; ===================== 脚本退出处理 =====================
; 在脚本退出前关闭数据库连接，确保数据完全写入
ExitFunc(ExitReason, ExitCode) {
    global ClipboardDB
    if FuncExists("HoleTriggers_RemoveMouseHook")
        try HoleTriggers_RemoveMouseHook()
    try Send("{CapsLock up}")
    try SetCapsLockState("Off")
    try NormalizeCapsLockRuntimeForUiOpen()
    try GDHO_HideOverlay()
    try NiumaTtyd_StopProcess()
    ; 退出时显式关闭 WebView 宿主与 Go 搜索核心，避免 msedgewebview2 / SearchCenterCore 残留占 CPU
    try {
        if (IsSet(SCWV_RequestHardClose) && Func(SCWV_RequestHardClose))
            SCWV_RequestHardClose("app_exit")
    } catch {
    }
    try {
        if ProcessExist("SearchCenterCore.exe")
            ProcessClose("SearchCenterCore.exe")
    } catch {
    }
    if (ClipboardDB && ClipboardDB != 0) {
        try {
            ClipboardDB.CloseDB()
        } catch as err {
            ; 忽略关闭错误
        }
    }
    try VK_OnHostExit()
}

; ========== VirtualKeyboard：同进程 Core + 对外 WM_COPYDATA（独立 VK 进程）==========
#Include modules\VirtualKeyboardExecCmd.ahk
#Include modules\VirtualKeyboardCore.ahk
#Include modules\VirtualKeyboardInterop.ahk
#Include "modules\ConfigWebViewModule.ahk"

; 命令面板可见时 Ctrl+Shift+O：OC-5 协议闭合探针（结果写入 Cache\debug\oc5_probe_last.json）
#HotIf CommandPalette_IsVisible()
^+o:: {
    try {
        if FuncExists("CommandPalette_RunOc5ProbeAndPersist")
            CommandPalette_RunOc5ProbeAndPersist()
        else if FuncExists("CommandPalette_ProbeOc5ProtocolClosure")
            CommandPalette_ProbeOc5ProtocolClosure()
        else
            try TrayTip("命令面板", "OC-5 探针未载入，请完全重启牛马脚本", "Iconx 2")
            catch {
            }
    } catch as e {
        try TrayTip("命令面板", "OC-5 探针失败: " . e.Message, "Iconx 2")
        catch {
        }
    }
}
; 命令面板可见时 Ctrl+Shift+U：Adapter A2UI 探针（结果写入 Cache\debug\adp_probe_last.json；需先 curl ingest 演示 JSONL）
^+u:: {
    try {
        if FuncExists("CommandPalette_RunAdapterProbeAndPersist")
            CommandPalette_RunAdapterProbeAndPersist()
        else if FuncExists("CommandPalette_ProbeAdapterOfficialA2ui")
            CommandPalette_ProbeAdapterOfficialA2ui()
        else
            try TrayTip("命令面板", "Adapter 探针未载入，请完全重启牛马脚本", "Iconx 2")
            catch {
            }
    } catch as e {
        try TrayTip("命令面板", "Adapter 探针失败: " . e.Message, "Iconx 2")
        catch {
        }
    }
}
; 命令面板可见时 Ctrl+Shift+G：A2UI 灰度路由探针（结果写入 Cache\debug\gray_probe_last.json）
^+g:: {
    try {
        if FuncExists("CommandPalette_RunGrayProbeAndPersist")
            CommandPalette_RunGrayProbeAndPersist()
        else if FuncExists("CommandPalette_ProbeGrayRoute")
            CommandPalette_ProbeGrayRoute()
        else
            try TrayTip("命令面板", "灰度探针未载入，请完全重启牛马脚本", "Iconx 2")
            catch {
            }
    } catch as e {
        try TrayTip("命令面板", "灰度探针失败: " . e.Message, "Iconx 2")
        catch {
        }
    }
}
; 命令面板可见时 Ctrl+Shift+A：诊断窗 · 动作托管标签
^+a:: {
    try {
        if FuncExists("CommandPalette_ShowSearchDebug")
            CommandPalette_ShowSearchDebug(true, "agent")
        else if FuncExists("CommandPalette_HandleAgentDebug")
            CommandPalette_HandleAgentDebug()
        else
            try TrayTip("命令面板", "诊断模块未载入，请完全重启牛马脚本", "Iconx 2")
            catch {
            }
    } catch as e {
        try TrayTip("命令面板", "诊断热键失败: " . e.Message, "Iconx 2")
        catch {
        }
    }
}
; 命令面板 WebView 聚焦时会吞全局 Ctrl+Shift+Q，宿主 $ 钩子兜底重载脚本
$^+q:: {
    try ReloadScriptFromPopupMenu()
    catch {
    }
}
#HotIf

; Cursor + CapsLock：动态右键菜单（须在 VirtualKeyboardCore 之后注册）
#HotIf WinActive("ahk_exe Cursor.exe") && CapsLockChordHotIf() && VK_ToolbarLayoutHasContextMenuItems()
RButton:: {
    VK_ShowToolbarLayoutContextMenu()
}
#HotIf

; 黑洞手势由 HoleActivationTriggers 内 WH_MOUSE_LL 钩子捕获（HoleTriggers_SyncInputCapture）

; A 启动层可见时 Esc 关闭（无需 CapsLock；WebView 无焦点时由宿主兜底）
#HotIf IsHoleRuntimeEnabledByActivationMode() && FuncExists("GDHO_IsLauncherLayerActive") && GDHO_IsLauncherLayerActive()
Esc:: {
    if FuncExists("GDHO_DismissLauncherOnEsc") && GDHO_DismissLauncherOnEsc("esc_hole_launcher")
        return
    Send("{Esc}")
}
#HotIf

; 保底全局热键：重启脚本（避免 Ctrl+Shift 组合被输入法/系统层抢占时 VK 动态绑定失效）
$^+q:: {
    try ReloadScriptFromPopupMenu()
}

OnExit(ExitFunc)
