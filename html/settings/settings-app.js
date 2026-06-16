
// --- settings iframe bridge (governance) ---
const __SETTINGS_SCOPE__ = window.__SETTINGS_SCOPE__ || null;
const __SETTINGS_CHILD__ = !!__SETTINGS_SCOPE__;
function __settingsPostToHost(payload) {
  const p = Object.assign({ v: 1, timestamp: Date.now() }, payload || {});
  if (p.action === undefined && p.type !== undefined) p.action = p.type;
  if (p.type === "testUserStudioLlm" && __SETTINGS_CHILD__) {
    try {
      const bridge = window.parent && window.parent.NmerSettingsBridge;
      if (bridge && typeof bridge.relayChildToAhk === "function") {
        bridge.relayChildToAhk(p, window);
        return;
      }
    } catch (_) {}
    try {
      window.parent.postMessage({ channel: "nmer-settings-child", payload: p }, "*");
      return;
    } catch (_) {}
    return;
  }
  if (window.chrome?.webview?.postMessage) {
    window.chrome.webview.postMessage(p);
    return;
  }
  if (__SETTINGS_CHILD__ && window.parent && window.parent !== window) {
    try {
      const bridge = window.parent.NmerSettingsBridge;
      if (bridge && typeof bridge.relayChildToAhk === "function") {
        bridge.relayChildToAhk(p, window);
        return;
      }
    } catch (_) {}
    window.parent.postMessage({ channel: "nmer-settings-child", payload: p }, "*");
  }
}

function __settingsAhkHostSync() {
  try {
    const topHo = window.top?.chrome?.webview?.hostObjects;
    if (topHo?.sync?.ahk) return topHo.sync.ahk;
    const ho = window.chrome?.webview?.hostObjects;
    if (ho?.sync?.ahk) return ho.sync.ahk;
  } catch (_) {}
  return null;
}

function __settingsStudioTestInline(payloadJson, testId, flat) {
  flat = flat || {};
  try {
    if (__SETTINGS_CHILD__) return null;
    const ahk = __settingsAhkHostSync();
    if (!ahk || typeof ahk.StudioTestLlm !== "function") return null;
    const raw = String(ahk.StudioTestLlm(
      String(payloadJson || ""),
      String(testId || ""),
      String(flat.llmApiKey || ""),
      String(flat.llmProvider || ""),
      String(flat.llmBaseUrl || ""),
      String(flat.llmModel || "")
    ) || "").trim();
    if (raw.startsWith("{")) return JSON.parse(raw);
    if (raw.startsWith("err:")) return { type: "testUserStudioLlmResult", ok: false, error: raw.slice(4) };
  } catch (e) {
    return { type: "testUserStudioLlmResult", ok: false, error: String(e?.message || e || "宿主调用失败") };
  }
  return null;
}

    if (typeof BasePanel === 'undefined') {
      window.BasePanel = {
        PROTO_VERSION: 1,
        postToAhk(obj) {
          const src = (obj && typeof obj === 'object' && !Array.isArray(obj)) ? obj : {};
          const p = Object.assign({ v: 1, timestamp: Date.now() }, src);
          if (p.action === undefined && p.type !== undefined) p.action = p.type;
          __settingsPostToHost(p);
        }
      };
    }
    const ALL_CATEGORIES = ["ai","cli","academic","baidu","image","audio","video","book","price","medical","cloud"];
    const DEFAULT_AI_ENGINES = [
      { id:"deepseek", icon:"https://app.local/assets/icons/app/DeepSeek.png", label:"DeepSeek" },
      { id:"yuanbao", icon:"https://app.local/assets/icons/app/yuanbao.png", label:"元宝" },
      { id:"doubao", icon:"https://app.local/assets/icons/app/doubao.png", label:"豆包" },
      { id:"zhipu", icon:"https://app.local/assets/icons/app/zhipu.png", label:"智谱" },
      { id:"mita", icon:"https://app.local/assets/icons/app/mita.png", label:"秘塔" },
      { id:"wenxin", icon:"https://app.local/assets/icons/app/wenxin.png", label:"文心一言" },
      { id:"qianwen", icon:"https://app.local/assets/icons/app/DeepSeek.png", label:"千问" },
      { id:"kimi", icon:"https://app.local/assets/icons/app/Kimi.png", label:"Kimi" },
      { id:"perplexity", icon:"https://app.local/assets/icons/app/Perplexity.png", label:"Perplexity" },
      { id:"copilot", icon:"https://app.local/assets/icons/app/Copilot.png", label:"Copilot" },
      { id:"chatgpt", icon:"https://app.local/assets/icons/app/ChatGPT.png", label:"ChatGPT" },
      { id:"grok", icon:"https://app.local/assets/icons/app/Grok.png", label:"Grok" },
      { id:"you", icon:"https://app.local/assets/icons/app/You.png", label:"You" },
      { id:"claude", icon:"https://app.local/assets/icons/app/Claude.png", label:"Claude" },
      { id:"monica", icon:"https://app.local/assets/icons/app/Monica.png", label:"Monica" },
      { id:"webpilot", icon:"https://app.local/assets/icons/app/WebPilot.png", label:"WebPilot" }
    ];
    const CLI_ENGINES = [
      { id:"codex", icon:"https://app.local/assets/icons/app/ChatGPT.png", label:"Codex" },
      { id:"gemini", icon:"https://app.local/assets/icons/app/DeepSeek.png", label:"Gemini" },
      { id:"openclaw", icon:"https://app.local/assets/icons/ai/openclaw.svg", label:"OpenClaw" },
      { id:"qwen", icon:"https://app.local/assets/icons/app/qwen.png", label:"Qwen" }
    ];
    const DEFAULT_CURSOR_SHORTCUTS = [
      { label: "命令面板", shortcut: "^+p", vkCommandId: "qa_command_palette", catalogId: "showCommands", desc: "Cursor 命令面板（悬浮栏可触发）" },
      { label: "终端", shortcut: "^+``", vkCommandId: "qa_terminal", catalogId: "toggleTerminal", desc: "打开集成终端" },
      { label: "全局搜索", shortcut: "^+f", vkCommandId: "qa_global_search", catalogId: "globalSearch", desc: "Cursor 工作区全局搜索" },
      { label: "资源管理器", shortcut: "^+e", vkCommandId: "qa_explorer", catalogId: "explorer", desc: "显示文件资源管理器侧栏" },
      { label: "源代码管理", shortcut: "^+g", vkCommandId: "qa_source_control", catalogId: "sourceControl", desc: "Git / 源代码管理视图" },
      { label: "扩展", shortcut: "^+x", vkCommandId: "qa_extensions", catalogId: "extensions", desc: "扩展市场侧栏" },
      { label: "简单浏览器", shortcut: "^+b", vkCommandId: "qa_browser", catalogId: "simpleBrowser", desc: "内置 Simple Browser" },
      { label: "编辑器设置", shortcut: "^+j", vkCommandId: "qa_settings", catalogId: "vscodeSettings", desc: "VS Code 设置" },
      { label: "Cursor 设置", shortcut: "^,", vkCommandId: "qa_cursor_settings", catalogId: "cursorSettings", desc: "Cursor 专属设置" }
    ];
    const FALLBACK_KEYBINDER_COMMANDS = [
      { id: "ch_f", name: "搜索中心", desc: "CapsLock+F：打开搜索中心", fn: "CH_RUN" },
      { id: "ch_x", name: "剪贴板管理", desc: "CapsLock+X：打开剪贴板面板", fn: "CH_RUN" },
      { id: "ch_q", name: "打开配置", desc: "CapsLock+Q：打开设置面板", fn: "CH_RUN" },
      { id: "ch_t", name: "智能截图", desc: "CapsLock+T：截图智能菜单", fn: "CH_RUN" },
      { id: "ch_p", name: "提示词采集", desc: "CapsLock+P：Prompt 快捷采集", fn: "CH_RUN" },
      { id: "ch_r", name: "牛马 Chat", desc: "CapsLock+R：打开悬浮条牛马对话抽屉", fn: "CH_RUN" },
      { id: "ch_b", name: "提示词", desc: "CapsLock+B：打开提示词快捷入口", fn: "CH_RUN" },
      { id: "ch_g", name: "显示虚拟键盘", desc: "CapsLock+G：打开 KeyBinder 窗口", fn: "CH_RUN" },
      { id: "sys_show_vk", name: "快捷键设置", desc: "打开 KeyBinder 快捷键面板", fn: "SHOW_VK" },
      { id: "ch_w", name: "方向上", desc: "CapsLock+W", fn: "CH_RUN" },
      { id: "ch_s", name: "方向下", desc: "CapsLock+S", fn: "CH_RUN" },
      { id: "ch_a", name: "方向左", desc: "CapsLock+A", fn: "CH_RUN" },
      { id: "ch_d", name: "方向右", desc: "CapsLock+D", fn: "CH_RUN" },
      { id: "ftm_reset_scale", name: "重置大小", desc: "悬浮工具栏右键：重置缩放", fn: "CH_RUN" },
      { id: "ftm_search_center", name: "搜索", desc: "悬浮工具栏右键：打开搜索中心", fn: "CH_RUN" },
      { id: "ftm_clipboard", name: "剪贴板", desc: "悬浮工具栏右键：打开剪贴板", fn: "CH_RUN" },
      { id: "ftm_minimize_to_edge", name: "最小化到边缘", desc: "悬浮工具栏右键：吸附到边缘", fn: "CH_RUN" },
      { id: "ftm_exit_app", name: "退出程序", desc: "悬浮工具栏右键：退出程序", fn: "CH_RUN" },
      { id: "ftm_hide_toolbar", name: "关闭工具栏", desc: "悬浮工具栏右键：隐藏工具栏", fn: "CH_RUN" },
      { id: "ftm_open_config", name: "打开设置", desc: "悬浮工具栏右键：打开设置", fn: "CH_RUN" },
      { id: "ftm_toggle_toolbar", name: "显示/隐藏工具栏", desc: "悬浮工具栏右键：切换可见性", fn: "CH_RUN" },
      { id: "ftm_reload_script", name: "重启脚本", desc: "悬浮工具栏右键：重载脚本", fn: "CH_RUN" },
      { id: "tray_show_search", name: "托盘/打开搜索中心", desc: "系统托盘右键菜单项", fn: "CH_RUN" },
      { id: "tray_show_clipboard", name: "托盘/打开剪贴板", desc: "系统托盘右键菜单项", fn: "CH_RUN" },
      { id: "tray_show_screenshot", name: "托盘/截图", desc: "系统托盘右键菜单项", fn: "CH_RUN" },
      { id: "tray_show_config", name: "托盘/打开设置", desc: "系统托盘右键菜单项", fn: "CH_RUN" },
      { id: "tray_toggle_toolbar", name: "托盘/显示隐藏工具栏", desc: "系统托盘右键菜单项", fn: "CH_RUN" },
      { id: "tray_hide_toolbar", name: "托盘/关闭工具栏", desc: "系统托盘右键菜单项", fn: "CH_RUN" },
      { id: "tray_reload_script", name: "托盘/重启脚本", desc: "系统托盘右键菜单项", fn: "CH_RUN" },
      { id: "tray_exit_app", name: "托盘/退出程序", desc: "系统托盘右键菜单项", fn: "CH_RUN" },
      { id: "qa_command_palette", name: "命令面板", desc: "Cursor: Ctrl+Shift+P", fn: "CH_RUN" },
      { id: "qa_terminal", name: "终端", desc: "Cursor: Ctrl+Shift+`", fn: "CH_RUN" },
      { id: "qa_global_search", name: "全局搜索", desc: "Cursor: Ctrl+Shift+F", fn: "CH_RUN" },
      { id: "qa_explorer", name: "资源管理器", desc: "Cursor: Ctrl+Shift+E", fn: "CH_RUN" },
      { id: "qa_source_control", name: "源代码管理", desc: "Cursor: Ctrl+Shift+G", fn: "CH_RUN" },
      { id: "qa_extensions", name: "扩展", desc: "Cursor: Ctrl+Shift+X", fn: "CH_RUN" },
      { id: "qa_browser", name: "简单浏览器", desc: "Cursor: Ctrl+Shift+B", fn: "CH_RUN" },
      { id: "qa_settings", name: "VS Code 设置", desc: "Cursor: Ctrl+Shift+J", fn: "CH_RUN" },
      { id: "qa_cursor_settings", name: "Cursor 设置", desc: "Cursor: Ctrl+,", fn: "CH_RUN" }
    ];
    const HK_SUB_TABS = [
      { id: "overview", label: "说明与手势" },
      { id: "cursor", label: "Cursor 组合键" },
      { id: "vk_nav", label: "全局导航" },
      { id: "vk_tray", label: "托盘与工具栏" },
      { id: "vk_dir", label: "方向键" },
      { id: "toolbar", label: "悬浮栏布局" }
    ];
    const HK_VK_PRESETS = [
      { id: "vk_nav", name: "全局导航", commands: ["ch_f", "ch_x", "ch_q", "ch_t", "ch_p", "ch_r", "ch_b", "ch_g", "sys_show_vk"] },
      {
        id: "vk_tray",
        name: "托盘与工具栏",
        commands: [
          "ftm_reset_scale", "ftm_search_center", "ftm_clipboard", "ftm_minimize_to_edge",
          "ftm_exit_app", "ftm_hide_toolbar", "ftm_open_config", "ftm_toggle_toolbar", "ftm_reload_script",
          "tray_show_search", "tray_show_clipboard", "tray_show_screenshot", "tray_show_config",
          "tray_toggle_toolbar", "tray_hide_toolbar", "tray_reload_script", "tray_exit_app"
        ]
      },
      { id: "vk_dir", name: "方向", commands: ["ch_w", "ch_s", "ch_a", "ch_d"] }
    ];
    const APP_SHORTCUT_REFERENCE = [
      { combo: "长按 CapsLock", label: "KeyBinder 快捷键面板", desc: "达到「通用设置」中的长按时间后弹出；可在下方关闭此行为，改从托盘打开虚拟键盘。" },
      { combo: "悬浮栏 · 搜索", label: "搜索中心", desc: "打开全局搜索中心，检索文件、剪贴板与 AI 能力。" },
      { combo: "悬浮栏 · 设置", label: "设置中心", desc: "打开本设置页面；与单键 Q 等效。" },
      { combo: "黑洞 · 划选文本", label: "唤起 Hub 交互", desc: "在「外观设置」中启用；划选文字后弹出 Hub 胶囊等交互（与激活模式相关）。" },
      { combo: "黑洞 · 顺时针画圈", label: "顺时针手势", desc: "在外观中启用后，按住右键顺时针画圈，识别成功后松手触发。" },
      { combo: "黑洞 · 逆时针画圈", label: "逆时针手势", desc: "在外观中启用后，按住右键逆时针画圈，识别成功后松手触发。" }
    ];
    const TOOLBAR_BUTTON_OPTIONS = [
      { id:"Search", name:"搜索" }, { id:"Record", name:"记录" }, { id:"Prompt", name:"提示词" },
      { id:"NewPrompt", name:"草稿本" }, { id:"Screenshot", name:"截图" }, { id:"Settings", name:"设置" }, { id:"VirtualKeyboard", name:"虚拟键盘" }
    ];
    const TOOLBAR_MENU_OPTIONS = [
      { id:"ToggleToolbar", name:"显示/隐藏工具栏" }, { id:"MinimizeToEdge", name:"最小化到边缘" }, { id:"ResetScale", name:"重置大小" },
      { id:"SearchCenter", name:"搜索中心" }, { id:"Clipboard", name:"剪贴板" }, { id:"OpenConfig", name:"打开设置" },
      { id:"HideToolbar", name:"关闭工具栏" }, { id:"ReloadScript", name:"重启脚本" }, { id:"ExitApp", name:"退出程序" }
    ];
    const DEFAULT_TOOLBAR_BUTTONS = ["Search","Record","Prompt","NewPrompt","Screenshot","Settings","VirtualKeyboard"];
    const DEFAULT_TOOLBAR_MENUS = ["ToggleToolbar","MinimizeToEdge","ResetScale","SearchCenter","Clipboard","OpenConfig","HideToolbar","ReloadScript","ExitApp"];
    const ACTIVATION_MODE_OPTIONS = [
      { value: "toolbar", label: "悬浮栏", desc: "显示完整悬浮条，适合重度高频操作。", iconClass: "fa-grip-lines", iconKind: "toolbar" },
      { value: "hole", label: "黑洞模式", desc: "独立黑洞交互入口；与悬浮栏互斥，不同时显示。", iconClass: "fa-circle-notch", iconKind: "hole" },
      { value: "tray", label: "后台", desc: "不显示任何悬浮窗，仅通过托盘图标使用功能。", iconClass: "fa-tray-arrow-up", iconKind: "tray" }
    ];
    const ACTIVATION_MODE_LOCAL_KEY = "settings.appearance.activationMode";
    const NIUMA_ICON_URL = "https://app.local/assets/%E7%89%9B%E9%A9%AC.png";
    const state = {
      activeTab: "general",
      selectedPromptTemplateId: "",
      promptsMainTab: "templateManager",
      promptsCategoryTab: "基础",
      promptsSearchKeyword: "",
      customPromptCategories: [],
      promptsSearchComposing: false,
      creatingPromptTemplate: false,
      screenshotSubTab: "capture",
      cursorRulesTab: "general",
      appearanceActivationMode: "toolbar",
      hotkeysSubTab: "overview",
      hkRecording: null,
      summonProbeReport: null,
      summonProbePending: false,
      summonProbeTimer: 0,
      summonAdvancedOpen: false,
      summonProbeExpanded: false,
      hkRecordHudText: "",
      hkCmdSearch: "",
      appUpdate: null,
      cacheInfo: null,
      migrationOptions: null,
      migrationPreset: "recommended",
      migrationSelectedGroups: null,
      fullText: {
        running: false,
        ready: false,
        progress: 0,
        progressText: "0.0%",
        indexing_file: "",
        indexVersion: "",
        engine_lights: ["off", "off", "off", "off"],
        config: {
          autoStart: true,
          workers: 2,
          indexDir: "",
          scanScheme: "auto",
          useUSN: true,
          includeLargeText: false,
          maxFileSizeMB: 8,
          scanSpeed: "normal",
          initialDelaySec: 1,
          pauseMS: 5
        }
      },
      fullTextProbe: {
        busy: false,
        last: null
      },
      healthSnapshot: null,
      healthSnapshotLoading: false,
      data: {
        cursorPath: "", capslockHoldTimeSeconds: 0.5, capsLockHoldVkEnabled: true, autoStart: false, defaultStartTab: "general",
        themeMode: "", popupScreenIndex: 1, monitorCount: 1,
        promptTemplateSummary: [],
        cursorRules: { general:"", web:"", miniprogram:"", android:"", ios:"", python:"" },
        cursorShortcuts: [],
        keybinderBindings: {},
        keybinderSuggestedBindings: {},
        promptQuickCaptureHotkey: "",
        summonHotkeyPreset: "capslock",
        summonHotkeyCustom: "",
        capsLockMode: "chord",
        hotkeyForceRevealAll: false,
        summonProbeReport: null,
        language: "zh", aiSleepTime: 200, launchDelaySeconds: 3.0,
        searchEngine: "deepseek", autoLoadSelectedText: false, autoUpdateVoiceInput: true,
        voiceSearchEnabledCategories: ["ai","cli","academic","baidu","image","audio","video","book","price","medical","cloud"],
        voiceSearchSelectedEnginesCsv: "deepseek",
        screenshotConfig: {
          captureMode: "selection",
          outputTarget: "editor",
          includeCursor: false,
          autoCopyClipboard: true,
          scalePercent: 100,
          imageFormat: "png",
          jpegQuality: 90,
          saveFilenamePattern: "Screenshot_{yyyyMMdd_HHmmss}",
          ocrEnhanceEnabled: true,
          ocrScalePrimary: 150,
          ocrScaleSecondary: 200,
          ocrUseGrayscale: true,
          ocrMonochromeLow: 160,
          ocrMonochromeHigh: 175,
          ocrUseInvert: true,
          ocrTextLayoutMode: "keep",
          ocrPunctuationMode: "keep",
          ocrDirectCopyEnabled: false
        },
        floatingToolbarButtons: [...DEFAULT_TOOLBAR_BUTTONS],
        floatingToolbarMenuItems: [...DEFAULT_TOOLBAR_MENUS],
        floatingToolbarButtonOptions: [...TOOLBAR_BUTTON_OPTIONS],
        floatingToolbarMenuOptions: [...TOOLBAR_MENU_OPTIONS],
        keybinderToolbarLayout: [],
        keybinderCommands: [],
        keybinderContextMenuLayout: [],
        appearanceActivationMode: "toolbar",
        holePositionMode: "anchor",
        holeTriggerDistance: 260,
        holeDismissDistance: 320,
        holeFixedX: 360,
        holeFixedY: 260,
        holeSizeScale: 1.0,
        holeAnimLevel: 1.0,
        holeVisualStyle: "ring",
        holeHideDockEnabled: true,
        holeHideDockEdge: "right",
        holeHideDockMargin: 10,
        holeTriggerTextSelect: true,
        holeTriggerCircleCw: false,
        holeTriggerCircleCcw: false,
        holeTriggerRButtonHold: false,
        holeRButtonHoldMs: 3000,
        holeSensitivityPreset: "standard",
        holePlacementPreset: "cursor"
      }
    };
    let __nmDock = null;
    let fullTextApplyTimer = 0;
    let ftbSortBar = null;
    let ftbSortPool = null;
    let ftbSaveTimer = 0;
    let menuSortBarCmds = null;
    let menuSortPoolCmds = null;
    let menuSortBarFixed = null;
    let menuSortPoolFixed = null;
    const FTB_SVG = {
      search: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>',
      prompt: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2"><path d="M12 3c4.97 0 9 3.58 9 8 0 1.8-.67 3.47-1.8 4.82L20 21l-5.02-1.67A10.53 10.53 0 0 1 12 20c-4.97 0-9-3.58-9-8s4.03-9 9-9Z"/></svg>',
      notepad: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3h11a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z"/><path d="M8 7h8"/><path d="M8 11h8"/><path d="M8 15h5"/></svg>',
      screenshot: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2"><path d="M4 7h4l2-2h4l2 2h4v12H4z"/><circle cx="12" cy="13" r="3.5"/></svg>',
      settings: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>',
      keyboard: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2.5" y="5" width="19" height="14" rx="2.5"/><path d="M6 9h1"/><path d="M9 9h1"/><path d="M12 9h1"/><path d="M15 9h1"/><path d="M18 9h1"/><path d="M6 12h1"/><path d="M9 12h1"/><path d="M12 12h1"/><path d="M15 12h1"/><path d="M18 12h1"/><path d="M7 15h10"/></svg>',
      clipboard: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="8" y="2" width="8" height="4" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/></svg>',
      comments: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/></svg>',
      list: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 6h13"/><path d="M8 12h13"/><path d="M8 18h13"/><path d="M3 6h.01"/><path d="M3 12h.01"/><path d="M3 18h.01"/></svg>',
      window: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M9 3v18"/></svg>',
      robot: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="8" width="14" height="10" rx="2"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/><circle cx="9.5" cy="13" r="1" fill="currentColor" stroke="none"/><circle cx="14.5" cy="13" r="1" fill="currentColor" stroke="none"/></svg>',
      bolt: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/></svg>',
      star: '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m12 2 2.4 7.4h7.6l-6 4.6 2.3 7-6.3-4.6-6.3 4.6 2.3-7-6-4.6h7.6z"/></svg>',
    };
    const FTB_CMD_KEY = { sc_activate_search: "search", qa_clipboard: "clipboard", hub_capsule: "notepad", ch_b: "prompt", pqp_capture: "bolt", ch_t: "screenshot", qa_config: "settings", sys_show_vk: "keyboard" };
    const FTB_FA_KEY = { "magnifying-glass": "search", clipboard: "clipboard", comments: "comments", lightbulb: "prompt", "note-sticky": "notepad", camera: "screenshot", gear: "settings", keyboard: "keyboard", list: "list", "window-restore": "window", robot: "robot", bolt: "bolt", star: "star", circle: "bolt", layer: "list", "layer-group": "list", terminal: "keyboard", sliders: "settings", code: "bolt", "wand-magic-sparkles": "prompt" };
    function destroyFtbWorkbenchSortable() {
      try { ftbSortBar?.destroy(); } catch {}
      try { ftbSortPool?.destroy(); } catch {}
      ftbSortBar = ftbSortPool = null;
    }
    function destroyMenuWorkbenchSortable() {
      try { menuSortBarCmds?.destroy(); } catch {}
      try { menuSortPoolCmds?.destroy(); } catch {}
      try { menuSortBarFixed?.destroy(); } catch {}
      try { menuSortPoolFixed?.destroy(); } catch {}
      menuSortBarCmds = menuSortPoolCmds = menuSortBarFixed = menuSortPoolFixed = null;
    }
    function buildKeybinderCommandMap() {
      const m = {};
      (state.data.keybinderCommands || []).forEach((c) => { if (c && c.id) m[c.id] = c; });
      FALLBACK_KEYBINDER_COMMANDS.forEach((c) => {
        if (c && c.id && !m[c.id]) m[c.id] = { ...c };
      });
      return m;
    }
    function mergeKeybinderCatalogFromHost(msg) {
      if (!msg || typeof msg !== "object") return false;
      let changed = false;
      if (Array.isArray(msg.commands) && msg.commands.length) {
        state.data.keybinderCommands = msg.commands;
        changed = true;
      }
      if (Array.isArray(msg.toolbarLayout)) {
        state.data.keybinderToolbarLayout = normalizeToolbarLayoutRows(msg.toolbarLayout);
        changed = true;
      }
      if (Array.isArray(msg.contextMenuLayout)) {
        state.data.keybinderContextMenuLayout = msg.contextMenuLayout;
        changed = true;
      }
      mergeKeybinderBindingsFromHost(msg.bindings, msg.suggestedBindings);
      return changed;
    }
    function requestKeybinderCatalogIfNeeded() {
      const needsCommands = !(Array.isArray(state.data.keybinderCommands) && state.data.keybinderCommands.length);
      const needsLayout = !(Array.isArray(state.data.keybinderToolbarLayout) && state.data.keybinderToolbarLayout.length);
      if (needsCommands || needsLayout) post({ type: "requestKeybinderCatalog" });
    }
    function cfgInferIconClass(cmd) {
      const t = `${cmd.id} ${cmd.name || ""}`.toLowerCase();
      if (/(search|搜|查|检索)/.test(t)) return "fa-magnifying-glass";
      if (/(clip|剪贴|复制|粘贴)/.test(t)) return "fa-clipboard";
      if (/(chat|send|对话|发送)/.test(t)) return "fa-comments";
      if (/(prompt|提示词|模板)/.test(t)) return "fa-lightbulb";
      if (/(draft|草稿|笔记)/.test(t)) return "fa-note-sticky";
      if (/(screen|截图|capture|ocr)/.test(t)) return "fa-camera";
      if (/(setting|设置|配置|config)/.test(t)) return "fa-gear";
      if (/(star|收藏)/.test(t)) return "fa-star";
      if (/(window|win_|最小化|关闭窗口)/.test(t)) return "fa-window-restore";
      if (/(ai|gpt|llm)/.test(t)) return "fa-robot";
      return "fa-bolt";
    }
    function cfgFaSuffix(iconClass) {
      let suf = "";
      String(iconClass || "").trim().split(/\s+/).forEach((p) => {
        if (p === "fa-solid" || p === "fa-brands" || p === "fa-regular") return;
        if (p.startsWith("fa-")) suf = p.slice(3);
      });
      return suf || "bolt";
    }
    function cfgToolbarIconSvg(cmdId, iconClassFull) {
      let key = FTB_CMD_KEY[String(cmdId || "").trim()];
      if (!key) {
        const suf = cfgFaSuffix(iconClassFull);
        key = FTB_FA_KEY[suf] || "bolt";
      }
      return FTB_SVG[key] || FTB_SVG.bolt;
    }
    function normalizeToolbarLayoutRows(arr) {
      const rows = Array.isArray(arr) ? arr : [];
      return rows.map((r) => {
        if (!r || !r.cmdId) return null;
        const vb = r.visible_in_bar !== undefined ? !!r.visible_in_bar : !!r.in_bar;
        const vm = r.visible_in_menu !== undefined ? !!r.visible_in_menu : !!r.in_context_menu;
        const ob = Number.isFinite(Number(r.order_bar)) ? Number(r.order_bar) : -1;
        const om = Number.isFinite(Number(r.order_menu)) ? Number(r.order_menu) : -1;
        const vsr = r.visible_in_search_row !== undefined ? !!r.visible_in_search_row : false;
        const osr = Number.isFinite(Number(r.order_search_row)) ? Number(r.order_search_row) : -1;
        const ms = Array.isArray(r.menu_scenes)
          ? r.menu_scenes.map((x) => String(x || '').trim()).filter(Boolean)
          : [];
        return {
          cmdId: String(r.cmdId),
          visible_in_bar: vb,
          visible_in_menu: vm,
          order_bar: ob,
          order_menu: om,
          visible_in_search_row: vsr,
          order_search_row: osr,
          menu_scenes: ms,
        };
      }).filter(Boolean);
    }
    function collectToolbarLayoutFromFtbDom() {
      if (!document.getElementById("cfg-ftb-bar")) {
        try {
          return JSON.parse(JSON.stringify(state.data.keybinderToolbarLayout || []));
        } catch {
          return [...(state.data.keybinderToolbarLayout || [])];
        }
      }
      const rows = [];
      const seen = new Set();
      const prevRows = normalizeToolbarLayoutRows(state.data.keybinderToolbarLayout || []);
      const prevById = new Map(prevRows.map((r) => [r.cmdId, r]));
      document.querySelectorAll("#cfg-ftb-bar .cfg-ftb-tile").forEach((el) => {
        const cid = String(el.dataset.cmdId || "").trim();
        if (!cid) return;
        const prev = prevById.get(cid) || {};
        rows.push({
          cmdId: cid,
          visible_in_bar: true,
          visible_in_menu: !!prev.visible_in_menu,
          order_bar: rows.length,
          order_menu: Number.isFinite(Number(prev.order_menu)) ? Number(prev.order_menu) : -1,
          visible_in_search_row: !!prev.visible_in_search_row,
          order_search_row: Number.isFinite(Number(prev.order_search_row)) ? Number(prev.order_search_row) : -1,
          menu_scenes: Array.isArray(prev.menu_scenes) ? [...prev.menu_scenes] : [],
        });
        seen.add(el.dataset.cmdId);
      });
      document.querySelectorAll("#cfg-shared-pool-ftb .cfg-ftb-tile").forEach((el) => {
        const cid = String(el.dataset.cmdId || "").trim();
        if (!cid) return;
        const prev = prevById.get(cid) || {};
        rows.push({
          cmdId: cid,
          visible_in_bar: !!prev.visible_in_bar,
          visible_in_menu: !!prev.visible_in_menu,
          order_bar: Number.isFinite(Number(prev.order_bar)) ? Number(prev.order_bar) : -1,
          order_menu: Number.isFinite(Number(prev.order_menu)) ? Number(prev.order_menu) : -1,
          visible_in_search_row: !!prev.visible_in_search_row,
          order_search_row: Number.isFinite(Number(prev.order_search_row)) ? Number(prev.order_search_row) : -1,
          menu_scenes: Array.isArray(prev.menu_scenes) ? [...prev.menu_scenes] : [],
        });
        seen.add(el.dataset.cmdId);
      });
      normalizeToolbarLayoutRows(state.data.keybinderToolbarLayout || []).forEach((r) => {
        if (r && r.cmdId && !seen.has(r.cmdId)) {
          seen.add(r.cmdId);
          rows.push({
            cmdId: r.cmdId,
            visible_in_bar: !!r.visible_in_bar,
            visible_in_menu: !!r.visible_in_menu,
            order_bar: Number.isFinite(Number(r.order_bar)) ? Number(r.order_bar) : -1,
            order_menu: Number.isFinite(Number(r.order_menu)) ? Number(r.order_menu) : -1,
            visible_in_search_row: !!r.visible_in_search_row,
            order_search_row: Number.isFinite(Number(r.order_search_row)) ? Number(r.order_search_row) : -1,
            menu_scenes: Array.isArray(r.menu_scenes) ? [...r.menu_scenes] : [],
          });
        }
      });
      return rows;
    }
    function mergeContextMenuFromMenuDom(rows) {
      const active = new Set([...document.querySelectorAll("#cfg-menu-bar-cmds .cfg-menu-tile")].map((el) => el.dataset.id));
      const cmdMap = buildKeybinderCommandMap();
      let menuOrder = 0;
      rows.forEach((row) => {
        const c = cmdMap[row.cmdId];
        const on = !!(c && c.fn === "CH_RUN" && active.has(row.cmdId));
        row.visible_in_menu = on;
        row.order_menu = on ? menuOrder++ : -1;
      });
    }
    function collectKeybinderWorkbenchPayload() {
      if (!document.getElementById("cfg-menu-bar-cmds")) {
        let tl;
        try {
          tl = JSON.parse(JSON.stringify(state.data.keybinderToolbarLayout || []));
        } catch {
          tl = [...(state.data.keybinderToolbarLayout || [])];
        }
        return {
          toolbarLayout: normalizeToolbarLayoutRows(tl),
          contextMenuLayout: [...(state.data.keybinderContextMenuLayout || [])],
        };
      }
      const toolbarLayout = collectToolbarLayoutFromFtbDom();
      mergeContextMenuFromMenuDom(toolbarLayout);
      const contextMenuLayout = [...document.querySelectorAll("#cfg-menu-bar-cmds .cfg-menu-tile")].map((el) => el.dataset.id);
      return { toolbarLayout, contextMenuLayout };
    }
    function scheduleKeybinderUnifiedSave() {
      if (ftbSaveTimer) clearTimeout(ftbSaveTimer);
      ftbSaveTimer = setTimeout(() => {
        ftbSaveTimer = 0;
        const payload = collectKeybinderWorkbenchPayload();
        state.data.keybinderToolbarLayout = normalizeToolbarLayoutRows(payload.toolbarLayout);
        state.data.keybinderContextMenuLayout = payload.contextMenuLayout;
        post({
          type: "saveKeybinderToolbarLayout",
          toolbarLayout: payload.toolbarLayout,
          contextMenuLayout: payload.contextMenuLayout,
        });
      }, 320);
    }
    function createFtbTileEl(cmdId, cmd, row, compact) {
      const icRaw = (cmd && cmd.iconClass) ? String(cmd.iconClass).trim() : "";
      let iconFull = "";
      if (icRaw) {
        if (/\bfa-(solid|brands|regular)\b/.test(icRaw)) iconFull = icRaw;
        else if (/^fa-[a-z0-9-]+$/i.test(icRaw)) iconFull = `fa-solid ${icRaw}`;
        else iconFull = `fa-solid ${cfgInferIconClass(cmd || { id: cmdId })}`;
      } else iconFull = `fa-solid ${cfgInferIconClass(cmd || { id: cmdId })}`;
      const wrap = document.createElement("div");
      wrap.className = "cfg-ftb-tile" + (compact ? " cfg-ftb-tile-compact" : "");
      wrap.dataset.cmdId = cmdId;
      wrap.title = (cmd && cmd.name) || cmdId;
      const ico = document.createElement("span");
      ico.className = "cfg-ftb-ico";
      ico.innerHTML = cfgToolbarIconSvg(cmdId, iconFull);
      if (compact) {
        wrap.append(ico);
      } else {
        const nm = document.createElement("div");
        nm.className = "cfg-ftb-tile-name";
        nm.textContent = (cmd && cmd.name) || cmdId;
        wrap.append(ico, nm);
      }
      return wrap;
    }
    function createMenuCmdTileEl(cmdId, cmd) {
      const wrap = document.createElement("div");
      wrap.className = "cfg-menu-tile cfg-menu-tile-cmd";
      wrap.dataset.kind = "cmd";
      wrap.dataset.id = cmdId;
      const title = (cmd && cmd.name) || cmdId;
      const desc = (cmd && cmd.desc) || "";
      wrap.title = desc ? `${title}\n${desc}` : title;
      const ico = document.createElement("span");
      ico.className = "cfg-menu-ico";
      const icRaw = (cmd && cmd.iconClass) ? String(cmd.iconClass).trim() : "";
      let iconFull = "";
      if (icRaw) {
        if (/\bfa-(solid|brands|regular)\b/.test(icRaw)) iconFull = icRaw;
        else if (/^fa-[a-z0-9-]+$/i.test(icRaw)) iconFull = `fa-solid ${icRaw}`;
        else iconFull = `fa-solid ${cfgInferIconClass(cmd || { id: cmdId })}`;
      } else iconFull = `fa-solid ${cfgInferIconClass(cmd || { id: cmdId })}`;
      ico.innerHTML = cfgToolbarIconSvg(cmdId, iconFull);
      const text = document.createElement("div");
      text.className = "cfg-menu-text";
      const t1 = document.createElement("div");
      t1.className = "cfg-menu-line1";
      t1.textContent = title;
      const t2 = document.createElement("div");
      t2.className = "cfg-menu-line2";
      t2.textContent = desc;
      text.append(t1, t2);
      wrap.append(ico, text);
      return wrap;
    }
    function mountMenuWorkbench() {
      const barC = document.getElementById("cfg-menu-bar-cmds");
      const poolC = document.getElementById("cfg-shared-pool-menu-cmds");
      if (!barC || !poolC) return;
      destroyMenuWorkbenchSortable();
      const cmdMap = buildKeybinderCommandMap();
      const chRun = (state.data.keybinderCommands || []).filter((c) => c && c.fn === "CH_RUN" && c.id && !String(c.id).startsWith("pt_"));
      const layout = normalizeToolbarLayoutRows(state.data.keybinderToolbarLayout || []);
      const activeSet = new Set(layout.filter((r) => r && r.visible_in_menu).map((r) => r.cmdId));
      const barCmdIds = [];
      const menuSorted = [...layout].filter((r) => r.visible_in_menu).sort((a, b) => (a.order_menu - b.order_menu));
      for (const row of menuSorted) {
        if (row && row.cmdId && !barCmdIds.includes(row.cmdId)) barCmdIds.push(row.cmdId);
      }
      for (const row of layout) {
        if (row && row.visible_in_menu && row.cmdId && !barCmdIds.includes(row.cmdId)) barCmdIds.push(row.cmdId);
      }
      const poolCmdIds = chRun.map((c) => c.id).filter((id) => !activeSet.has(id));
      barC.innerHTML = "";
      poolC.innerHTML = "";
      barCmdIds.forEach((id) => {
        const c = cmdMap[id];
        if (c) barC.appendChild(createMenuCmdTileEl(id, c));
      });
      poolCmdIds.forEach((id) => {
        const c = cmdMap[id];
        if (c) poolC.appendChild(createMenuCmdTileEl(id, c));
      });
      if (typeof Sortable === "undefined") return;
      const so = { animation: 150, ghostClass: "sortable-ghost", dragClass: "sortable-drag", onEnd: scheduleKeybinderUnifiedSave };
      menuSortBarCmds = new Sortable(barC, { ...so, group: "menuRun" });
      menuSortPoolCmds = new Sortable(poolC, { ...so, group: "menuRun" });
    }
    function rowToolbarEligible(row) {
      if (!row) return false;
      return !!(row.visible_in_bar || row.visible_in_menu);
    }
    function mountFtbWorkbench() {
      const bar = document.getElementById("cfg-ftb-bar");
      const pool = document.getElementById("cfg-shared-pool-ftb");
      if (!bar || !pool) return;
      const cmdMap = buildKeybinderCommandMap();
      const layout = normalizeToolbarLayoutRows(state.data.keybinderToolbarLayout || []);
      bar.innerHTML = "";
      pool.innerHTML = "";
      for (const row of layout) {
        const c = cmdMap[row.cmdId];
        if (!c || !rowToolbarEligible(row)) continue;
        if (row.visible_in_bar) bar.appendChild(createFtbTileEl(row.cmdId, c, row, true));
      }
      for (const row of layout) {
        const c = cmdMap[row.cmdId];
        if (!c || !rowToolbarEligible(row)) continue;
        if (!row.visible_in_bar) pool.appendChild(createFtbTileEl(row.cmdId, c, row, false));
      }
      if (typeof Sortable === "undefined") return;
      destroyFtbWorkbenchSortable();
      const opt = { group: "cfg-ftb", animation: 150, ghostClass: "sortable-ghost", dragClass: "sortable-drag", onEnd: scheduleKeybinderUnifiedSave };
      ftbSortBar = new Sortable(bar, opt);
      ftbSortPool = new Sortable(pool, opt);
    }
    const post = (msg) => BasePanel.postToAhk(msg);
    const trace = (event, detail, extra) => {
      const p = {
        type: "settingsTrace",
        source: __SETTINGS_CHILD__ ? "app_child" : "app_top",
        event: String(event || ""),
        detail: String(detail || ""),
        tab: String(state.activeTab || "")
      };
      if (extra && typeof extra === "object") Object.assign(p, extra);
      try { post(p); } catch (_) {}
    };
    let statusPinUntil = 0;
    const setStatus = (text, cls = "", opts) => {
      opts = opts || {};
      if (!opts.force && Date.now() < statusPinUntil) return;
      const el = document.getElementById("status");
      const s = String(text || "");
      el.textContent = s;
      el.title = s.includes("\n") ? s : "";
      el.style.whiteSpace = s.includes("\n") ? "pre-wrap" : "";
      el.className = cls;
    };
    const pinStatus = (text, cls = "", ms = 15000) => {
      statusPinUntil = Date.now() + ms;
      setStatus(text, cls, { force: true });
    };
    const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (ch) => ({ "&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#39;" }[ch]));
    const checked = (v) => v ? "checked" : "";
    let suppressAutoSave = true;
    let initDataReceived = false;
    const lazyInitDone = {
      probeVk: false,
      keybinderCatalog: false,
      fullTextStatus: false,
      studioStatus: false,
      healthSnapshot: false,
      cacheInfo: false,
      migrationOptions: false
    };
    function scopeHasTab(tab) {
      if (!__SETTINGS_SCOPE__ || !Array.isArray(__SETTINGS_SCOPE__.tabs)) return true;
      return __SETTINGS_SCOPE__.tabs.includes(String(tab || ""));
    }
    function runLazyOnce(key, fn, delay = 80) {
      if (lazyInitDone[key]) return;
      lazyInitDone[key] = true;
      setTimeout(() => {
        try { fn(); } catch (_) {}
      }, Math.max(0, Number(delay) || 0));
    }
    function runLazyInitForTab(tab, reason = "") {
      const t = String(tab || "");
      if (t === "hotkeys" && scopeHasTab("hotkeys")) {
        runLazyOnce("probeVk", () => post({ type: "probeVk", reason: reason || "lazy_hotkeys" }), 40);
        runLazyOnce("keybinderCatalog", () => requestKeybinderCatalogIfNeeded(), 70);
        return;
      }
      if (t === "search" && scopeHasTab("search")) {
        runLazyOnce("fullTextStatus", () => requestFullTextStatus(true), 90);
        return;
      }
      if (t === "customize" && scopeHasTab("customize")) {
        runLazyOnce("studioStatus", async () => {
          await Promise.all([
            refreshStudioHermesStatusAsync().catch(() => {}),
            refreshStudioOpenClawStatusAsync().catch(() => {})
          ]);
        }, 140);
        return;
      }
      if (t === "advanced" && scopeHasTab("advanced")) {
        runLazyOnce("healthSnapshot", () => requestHealthSnapshot("open_panel"), 120);
        return;
      }
      if (t === "storage" && scopeHasTab("storage")) {
        runLazyOnce("cacheInfo", () => requestCacheInfo(), 100);
        runLazyOnce("migrationOptions", () => requestMigrationOptions(), 130);
      }
    }
    /** 用户是否在「通用设置」改过默认启动页；未置位时自动保存不得带上 defaultStartTab */
    let defaultStartTabDirty = false;
    const HOLE_SAVE_KEYS = [
      "holePositionMode", "holeTriggerDistance", "holeDismissDistance", "holeFixedX", "holeFixedY",
      "holeSizeScale", "holeAnimLevel", "holeVisualStyle", "holeHideDockEnabled", "holeHideDockEdge",
      "holeHideDockMargin", "holeTriggerTextSelect", "holeTriggerCircleCw", "holeTriggerCircleCcw",
      "holeTriggerRButtonHold", "holeRButtonHoldMs", "holeSensitivityPreset", "holePlacementPreset"
    ];
    let saveInFlight = false;
    let pendingSaveHash = "";
    let lastSentHash = "";
    let lastSavedHash = "";
    let activationModeSaveTimer = 0;
    function stableStringify(v){
      const seen = new WeakSet();
      const sortObj = (x) => {
        if (!x || typeof x !== "object") return x;
        if (seen.has(x)) return null;
        seen.add(x);
        if (Array.isArray(x)) return x.map(sortObj);
        const out = {};
        Object.keys(x).sort().forEach((k) => { out[k] = sortObj(x[k]); });
        return out;
      };
      try { return JSON.stringify(sortObj(v)); } catch { return ""; }
    }
    function captureGeneralTabState() {
      if (!document.getElementById("cursorPath")) return;
      state.data = readGeneral({ ...state.data });
    }
    function buildSavePayloadFromDom(d) {
      const p = { monitorCount: d.monitorCount };
      if (document.getElementById("cursorPath")) {
        p.cursorPath = d.cursorPath;
        p.capslockHoldTimeSeconds = d.capslockHoldTimeSeconds;
        p.capsLockHoldVkEnabled = d.capsLockHoldVkEnabled;
        p.autoStart = d.autoStart;
        if (defaultStartTabDirty) p.defaultStartTab = d.defaultStartTab;
      }
      if (document.getElementById("themeMode")) p.themeMode = d.themeMode;
      if (document.getElementById("popupScreenIndex")) p.popupScreenIndex = d.popupScreenIndex;
      if (document.getElementById("holePlacementPreset")) {
        for (const k of HOLE_SAVE_KEYS) if (k in d) p[k] = d[k];
      }
      if (document.querySelector('input[name="activationMode"]')) p.appearanceActivationMode = d.appearanceActivationMode;
      if (document.getElementById("cursorRuleContent")) p.cursorRules = d.cursorRules;
      if (document.getElementById("aiSleepTimeSeconds")) {
        p.language = d.language;
        p.aiSleepTime = d.aiSleepTime;
        p.launchDelaySeconds = d.launchDelaySeconds;
      }
      if (document.getElementById("toolbarButtonsList")) p.floatingToolbarButtons = d.floatingToolbarButtons;
      if (document.getElementById("toolbarMenusList")) p.floatingToolbarMenuItems = d.floatingToolbarMenuItems;
      if (document.getElementById("promptQuickCaptureHotkey")) p.promptQuickCaptureHotkey = d.promptQuickCaptureHotkey;
      if (document.getElementById("btnCapsLockLayerToggle")) {
        p.summonHotkeyPreset = "capslock";
        p.summonHotkeyCustom = "";
        p.capsLockMode = d.capsLockMode;
        p.capsLockHoldVkEnabled = d.capsLockHoldVkEnabled;
        p.hotkeyForceRevealAll = !!d.hotkeyForceRevealAll;
      }
      if (document.getElementById("ssCaptureMode") && d.screenshotConfig) p.screenshotConfig = d.screenshotConfig;
      if (document.getElementById("ddDefaultEngine") || document.getElementById("autoLoadSelectedText")) {
        p.searchEngine = d.searchEngine;
        p.autoLoadSelectedText = d.autoLoadSelectedText;
        p.autoUpdateVoiceInput = d.autoUpdateVoiceInput;
        p.voiceSearchEnabledCategories = d.voiceSearchEnabledCategories;
        p.voiceSearchSelectedEnginesCsv = d.voiceSearchSelectedEnginesCsv;
      }
      if (document.getElementById("studioLlmCards") || document.getElementById("usLlmApiKey")) p.userStudio = d.userStudio;
      return p;
    }
    function pruneSettingsPayload(d) {
      return buildSavePayloadFromDom(d);
    }
    function validatePayload(d) {
      if ("cursorPath" in d) {
        if (!d.cursorPath) return "Cursor 路径不能为空";
        if (!(d.capslockHoldTimeSeconds >= 0.1 && d.capslockHoldTimeSeconds <= 5.0)) return "CapsLock Hold Time 需要在 0.1 到 5.0 之间";
      }
      if ("popupScreenIndex" in d) {
        if (!Number.isInteger(d.popupScreenIndex) || d.popupScreenIndex < 1) return "弹窗屏幕序号非法";
        const maxMonitors = Math.max(1, Number(d.monitorCount || 1));
        if (d.popupScreenIndex > maxMonitors) return "弹窗屏幕序号超出显示器范围";
      }
      const hasHole = HOLE_SAVE_KEYS.some((k) => k in d);
      if (hasHole) {
        if (!["cursor","fixed","edge"].includes(String(d.holePlacementPreset || "cursor"))) return "黑洞出现位置非法";
        const trigErr = validateHoleTriggers(d);
        if (trigErr) return trigErr;
        if (![1000, 3000, 5000].includes(normalizeHoleRButtonHoldMs(d.holeRButtonHoldMs))) return "长按右键时长非法";
        if (!["anchor","fixed","relative"].includes(String(d.holePositionMode || "anchor"))) return "黑洞位置模式非法";
        if (!Number.isFinite(Number(d.holeTriggerDistance)) || Number(d.holeTriggerDistance) < 80 || Number(d.holeTriggerDistance) > 1200) return "黑洞触发距离非法";
        if (!Number.isFinite(Number(d.holeDismissDistance)) || Number(d.holeDismissDistance) < 120 || Number(d.holeDismissDistance) > 1600) return "黑洞消失距离非法";
        if (!Number.isFinite(Number(d.holeSizeScale)) || Number(d.holeSizeScale) < 0.85 || Number(d.holeSizeScale) > 1.5) return "黑洞大小非法";
        if (!["ring","starry"].includes(String(d.holeVisualStyle || "ring"))) return "黑洞样式非法";
        if (!["right","left","top","bottom"].includes(String(d.holeHideDockEdge || "right"))) return "黑洞隐藏吸附边缘非法";
        if (!Number.isFinite(Number(d.holeHideDockMargin)) || Number(d.holeHideDockMargin) < 0 || Number(d.holeHideDockMargin) > 80) return "黑洞隐藏吸附边距非法";
      }
      if ("aiSleepTime" in d) {
        if (!Number.isInteger(d.aiSleepTime) || d.aiSleepTime < 50) return "AI 等待时间非法";
      }
      if ("launchDelaySeconds" in d) {
        if (!(d.launchDelaySeconds >= 0.5 && d.launchDelaySeconds <= 10)) return "启动延迟时间非法";
      }
      return "";
    }
    function postSaveGeneral(patch) {
      captureGeneralTabState();
      const payload = { ...patch };
      if (payload.cursorPath === undefined && state.data.cursorPath) payload.cursorPath = state.data.cursorPath;
      post({ type: "saveGeneralSettings", payload });
    }
    function patchSettingsControl(t) {
      if (!t || !t.id) return;
      if (t.id === "autoStart") state.data.autoStart = !!t.checked;
      else if (t.id === "holdTime") state.data.capslockHoldTimeSeconds = Number(t.value);
      else if (t.id === "cursorPath") state.data.cursorPath = t.value.trim();
      else if (t.id === "capsLockHoldVkEnabled") state.data.capsLockHoldVkEnabled = !!t.checked;
    }
    function tryAutoSaveNow(silent = false){
      const d = pruneSettingsPayload(readFromUI());
      if (!Object.keys(d).length) return;
      const err = validatePayload(d);
      if (err) {
        if (!silent) setStatus(err, "err");
        return;
      }
      const hash = stableStringify(d);
      if (!hash) return;
      if (hash === lastSavedHash || hash === lastSentHash) return;
      if (saveInFlight) {
        pendingSaveHash = hash;
        return;
      }
      saveInFlight = true;
      lastSentHash = hash;
      pendingSaveHash = "";
      if (!silent) setStatus("自动保存中...");
      post({ type: "saveSettings", payload: d });
    }
    let settingsPersistTimer = 0;
    function scheduleSettingsPersist(silent = true) {
      if (suppressAutoSave || !initDataReceived) return;
      if (settingsPersistTimer) clearTimeout(settingsPersistTimer);
      settingsPersistTimer = setTimeout(() => {
        settingsPersistTimer = 0;
        tryAutoSaveNow(silent);
      }, 500);
    }
    function flushSettingsTab() {
      if (settingsPersistTimer) {
        clearTimeout(settingsPersistTimer);
        settingsPersistTimer = 0;
      }
      tryAutoSaveNow(true);
    }
    window.__nmerFlushSettingsTab = flushSettingsTab;
    function scheduleSaveAppearanceActivationMode(delay = 120) {
      if (activationModeSaveTimer) clearTimeout(activationModeSaveTimer);
      activationModeSaveTimer = setTimeout(() => {
        activationModeSaveTimer = 0;
        post({ type: "saveAppearanceActivationMode", mode: state.appearanceActivationMode });
      }, delay);
    }
    function bindAutoSaveControls(){}
    function normalizeFullTextPayload(payload){
      const next = { ...(state.fullText || {}) };
      const src = payload && typeof payload === "object" ? payload : {};
      next.running = !!src.running;
      next.ready = !!src.ready;
      next.progress = Number.isFinite(Number(src.progress)) ? Number(src.progress) : 0;
      next.progressText = String(src.progressText || `${next.progress.toFixed(1)}%`);
      next.indexing_file = String(src.indexing_file || "");
      next.indexVersion = String(src.indexVersion || next.indexVersion || "");
      next.scanPhase = String(src.scanPhase || next.scanPhase || "");
      next.discoveredFiles = Number.isFinite(Number(src.discoveredFiles)) ? Number(src.discoveredFiles) : Number(next.discoveredFiles || 0);
      next.processedFiles = Number.isFinite(Number(src.processedFiles)) ? Number(src.processedFiles) : Number(next.processedFiles || 0);
      next.pendingTasks = Number.isFinite(Number(src.pendingTasks)) ? Number(src.pendingTasks) : Number(next.pendingTasks || 0);
      next.queueCapacity = Number.isFinite(Number(src.queueCapacity)) ? Number(src.queueCapacity) : Number(next.queueCapacity || 0);
      next.engine_lights = Array.isArray(src.engine_lights) && src.engine_lights.length === 4
        ? src.engine_lights.map(v => String(v || "off"))
        : ["off","off","off","off"];
      next.lastError = String(src.lastError || "");
      const cfgSrc = src.config && typeof src.config === "object" ? src.config : (next.config || {});
      next.config = {
        autoStart: cfgSrc.autoStart !== false,
        workers: Math.max(1, Number(cfgSrc.workers || 2)),
        indexDir: String(cfgSrc.indexDir || ""),
        scanScheme: String(cfgSrc.scanScheme || "auto"),
        useUSN: (typeof cfgSrc.useUSN === "boolean") ? cfgSrc.useUSN : true,
        includeLargeText: !!cfgSrc.includeLargeText,
        maxFileSizeMB: Math.max(1, Number(cfgSrc.maxFileSizeMB || 8)),
        scanSpeed: String(cfgSrc.scanSpeed || "normal"),
        initialDelaySec: Math.max(1, Number(cfgSrc.initialDelaySec || 1)),
        pauseMS: Math.max(0, Number(cfgSrc.pauseMS ?? 5))
      };
      return next;
    }
    function buildFullTextTaskText(ft){
      const discovered = Number(ft.discoveredFiles) || 0;
      const processed = Number(ft.processedFiles) || 0;
      const pending = Number(ft.pendingTasks) || 0;
      const queueCap = Number(ft.queueCapacity) || 0;
      const phase = String(ft.scanPhase || "");
      const hasActiveQueue = pending > 0 || (discovered > 0 && processed < discovered);
      const activeBusy = !!ft.running && (phase === "walking" || phase === "indexing" || hasActiveQueue);
      if (ft.indexing_file) return String(ft.indexing_file);
      if (activeBusy) {
        if (phase === "walking") return "正在扫描目录…";
        if (pending > 0) return queueCap > 0 ? `正在建立索引（队列 ${pending}/${queueCap}）` : `正在建立索引（队列 ${pending}）`;
        return "正在建立索引…";
      }
      if (ft.running && phase === "idle_wait") return "等待空闲后开始索引…";
      if (ft.ready) return "索引已就绪（当前无索引任务）";
      if (!ft.running) return "索引已停止（当前无索引任务）";
      return "当前无索引任务";
    }
    function requestFullTextStatus(withConfig = false){
      post({ type: "fulltextStatusRequest", withConfig: !!withConfig });
    }
    function requestFullTextProbe(){
      state.fullTextProbe.busy = true;
      setFullTextProbeSummary("正在检测可行性…");
      post({ type: "fulltextProbeRequest" });
    }
    function schemeDisplayName(scheme){
      const v = String(scheme || "auto").toLowerCase();
      if (v === "mft") return "高速扫描（推荐）";
      if (v === "everything") return "快速扫描（需 Everything）";
      if (v === "walk") return "兼容扫描（最稳定）";
      return "自动选择（推荐）";
    }
    function setFullTextProbeSummary(text){
      const el = document.getElementById("ftProbeSummary");
      if (!el) return;
      el.textContent = String(text || "");
    }
    function renderFullTextProbe(probe){
      state.fullTextProbe.last = probe && typeof probe === "object" ? probe : null;
      const box = document.getElementById("ftProbeList");
      if (!box) return;
      const p = state.fullTextProbe.last;
      if (!p) {
        box.innerHTML = "";
        setFullTextProbeSummary("");
        return;
      }
      const rows = Array.isArray(p.rootChecks) ? p.rootChecks : [];
      if (!rows.length) {
        box.innerHTML = "<div class=\"ft-probe-item\">未返回分盘检测结果</div>";
      } else {
        box.innerHTML = rows.map((item) => {
          const root = String(item.root || "-");
          const mftOk = !!item.mftOk;
          const usnOk = !!item.usnOk;
          const mftReason = String(item.mftReason || "");
          const usnReason = String(item.usnReason || "");
          return `<div class=\"ft-probe-item\"><strong>${esc(root)}</strong><br>高速扫描: <span class=\"${mftOk ? "ft-probe-ok" : "ft-probe-bad"}\">${mftOk ? "可用" : "不可用"}</span> · ${esc(mftReason)}<br>实时更新: <span class=\"${usnOk ? "ft-probe-ok" : "ft-probe-bad"}\">${usnOk ? "可用" : "不可用"}</span> · ${esc(usnReason)}</div>`;
        }).join("");
      }
      const rec = String(p.recommendedScheme || "auto").toLowerCase();
      const cur = String(document.getElementById("ftScanScheme")?.value || state.fullText?.config?.scanScheme || "auto").toLowerCase();
      if (rec === cur) {
        setFullTextProbeSummary(`当前方式：${schemeDisplayName(cur)}（与推荐一致）`);
      } else {
        setFullTextProbeSummary(`当前方式：${schemeDisplayName(cur)} · 推荐方式：${schemeDisplayName(rec)}`);
      }
    }
    function applyRecommendedFullTextScheme(){
      const rec = state.fullTextProbe && state.fullTextProbe.last
        ? String(state.fullTextProbe.last.recommendedScheme || "").toLowerCase()
        : "";
      const useRec = (rec === "mft" || rec === "everything" || rec === "walk" || rec === "auto") ? rec : "auto";
      const sel = document.getElementById("ftScanScheme");
      if (sel) sel.value = useRec;
      scheduleFullTextApply(10);
    }
    function readFullTextConfigFromUI(){
      return {
        autoStart: !!document.getElementById("ftAutoStart")?.checked,
        workers: Math.max(1, Number(document.getElementById("ftWorkers")?.value || 2)),
        indexDir: String(document.getElementById("ftIndexDir")?.value || "").trim(),
        scanScheme: String(document.getElementById("ftScanScheme")?.value || "auto"),
        useUSN: !!document.getElementById("ftUseUSN")?.checked,
        includeLargeText: !!document.getElementById("ftIncludeLarge")?.checked,
        maxFileSizeMB: Math.max(1, Number(document.getElementById("ftMaxFileMB")?.value || 8)),
        scanSpeed: String(document.getElementById("ftScanSpeed")?.value || "normal"),
        initialDelaySec: Math.max(1, Number(document.getElementById("ftInitialDelay")?.value || 1)),
        pauseMS: Math.max(0, Number(document.getElementById("ftPauseMS")?.value || 5))
      };
    }
    function scheduleFullTextApply(delay = 320){
      if (fullTextApplyTimer) clearTimeout(fullTextApplyTimer);
      fullTextApplyTimer = setTimeout(() => {
        const payload = readFullTextConfigFromUI();
        post({ type: "fulltextConfigUpdate", payload });
      }, delay);
    }
    function bindFullTextConsoleControls(){
      const ids = ["ftAutoStart","ftWorkers","ftIndexDir","ftScanScheme","ftUseUSN","ftIncludeLarge","ftMaxFileMB","ftScanSpeed","ftInitialDelay","ftPauseMS"];
      ids.forEach((id) => {
        const el = document.getElementById(id);
        if (!el) return;
        const evt = el.type === "checkbox" || el.tagName === "SELECT" ? "change" : "input";
        el.addEventListener(evt, () => scheduleFullTextApply());
      });
      document.getElementById("btnFtToggle")?.addEventListener("click", () => {
        const act = state.fullText && state.fullText.running ? "stop" : "start";
        post({ type: "fulltextControl", control: act });
      });
      document.getElementById("btnFtRefresh")?.addEventListener("click", () => requestFullTextStatus(true));
      document.getElementById("btnFtPickDir")?.addEventListener("click", () => post({ type: "fulltextPickIndexDir" }));
      document.getElementById("btnFtProbe")?.addEventListener("click", () => requestFullTextProbe());
      document.getElementById("btnFtRecommend")?.addEventListener("click", () => applyRecommendedFullTextScheme());
      document.getElementById("btnFtRoots")?.addEventListener("click", async () => {
        try {
          const res = await fetch("http://127.0.0.1:8080/v1/fulltext/roots");
          if (!res.ok) throw new Error("fetch failed");
          const data = await res.json();
          const candidates = Array.isArray(data.wizardCandidates) ? data.wizardCandidates : [];
          const current = Array.isArray(data.resolution && data.resolution.roots) ? data.resolution.roots : candidates;
          const picked = window.prompt("输入要索引的目录（每行一个）", current.join("\n"));
          if (!picked) return;
          const roots = picked.split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
          if (!roots.length) return;
          const confirmRes = await fetch("http://127.0.0.1:8080/v1/fulltext/roots/confirm", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ roots, remember: true })
          });
          if (!confirmRes.ok) throw new Error("confirm failed");
          setStatus("索引范围已更新", "ok");
          requestFullTextStatus(true);
        } catch (e) {
          setStatus("更新索引范围失败：" + String(e && e.message || e), "err");
        }
      });
      document.getElementById("btnFtRebuild")?.addEventListener("click", async () => {
        const ok = await (window.nmConfirm ? window.nmConfirm(
          "重建全文索引？",
          "将清空并重建全文索引，用于验证单字检索。是否继续？",
          { okLabel: "重建", cancelLabel: "取消", danger: true }
        ) : Promise.resolve(window.confirm("将清空并重建全文索引，用于验证单字检索。是否继续？")));
        if (!ok) return;
        setStatus("已触发强制重建索引，正在准备…", "ok");
        post({ type: "fulltextControl", control: "rebuild" });
      });
    }
    function refreshFullTextConsoleDom(){
      if (state.activeTab !== "search") return;
      const ft = normalizeFullTextPayload(state.fullText);
      state.fullText = ft;
      const lights = document.querySelectorAll("[data-ft-light]");
      lights.forEach((el, idx) => {
        const st = ft.engine_lights[idx] || "off";
        el.className = `ft-light ${st}`;
      });
      const summary = document.getElementById("ftSummary");
      if (summary) summary.textContent = `${ft.running ? "运行中" : "已停止"} · ${ft.ready ? "已就绪" : "构建中"} · ${ft.progressText || `${ft.progress.toFixed(1)}%`}`;
      const ver = document.getElementById("ftVersion");
      if (ver) ver.textContent = `索引版本 ${ft.indexVersion || "-"}`;
      const bar = document.getElementById("ftProgressBar");
      if (bar) bar.style.width = `${Math.max(0, Math.min(100, Number(ft.progress || 0))).toFixed(1)}%`;
      const file = document.getElementById("ftCurrentFile");
      if (file) {
        const txt = buildFullTextTaskText(ft);
        file.textContent = txt;
        file.title = txt;
      }
      const hint = document.getElementById("ftHint");
      if (hint) hint.textContent = ft.lastError || "设置会自动保存并自动应用到索引引擎。";
      const scanScheme = document.getElementById("ftScanScheme");
      if (scanScheme) scanScheme.value = String(ft.config?.scanScheme || "auto");
      const useUSN = document.getElementById("ftUseUSN");
      if (useUSN) useUSN.checked = !!ft.config?.useUSN;
      renderFullTextProbe(state.fullTextProbe.last);
      const toggleBtn = document.getElementById("btnFtToggle");
      if (toggleBtn) {
        if (ft.running) {
          toggleBtn.textContent = "停止索引";
          toggleBtn.title = "点击停止全文索引";
        } else {
          toggleBtn.textContent = "启动索引";
          toggleBtn.title = "点击启动全文索引";
        }
      }
    }
    function loadCustomCategories(){
      try {
        const raw = localStorage.getItem("settings.prompts.customCategories");
        const arr = JSON.parse(raw || "[]");
        if (Array.isArray(arr)) {
          state.customPromptCategories = arr.map(v => String(v || "").trim()).filter(Boolean);
        }
      } catch {}
    }
    function saveCustomCategories(){
      try {
        localStorage.setItem("settings.prompts.customCategories", JSON.stringify(state.customPromptCategories || []));
      } catch {}
    }
    function normalizeDefaultStartTab(tab) {
      const zh = {
        "通用": "general", "通用设置": "general",
        "外观": "appearance", "外观设置": "appearance",
        "提示词": "prompts", "提示词设置": "prompts",
        "快捷键": "hotkeys", "快捷键设置": "hotkeys",
        "高级": "advanced", "高级设置": "advanced",
        "搜索": "search", "搜索设置": "search",
        "截图": "screenshot", "截图设置": "screenshot",
        "存储": "storage", "存储与缓存": "storage",
        "智能定制": "customize", "定制": "customize"
      };
      const t = String(tab || "").trim();
      if (zh[t]) return zh[t];
      const valid = new Set(["general","appearance","prompts","hotkeys","advanced","storage","screenshot","search","customize"]);
      return valid.has(t) ? t : "general";
    }
    function updateHkVkStatusDom(available) {
      const el = document.getElementById("hk-vk-status");
      if (!el) return;
      if (available === true) {
        el.textContent = "VK KeyBinder 已就绪";
        el.className = "hk-vk-status ok";
      } else if (available === false) {
        el.textContent = "VK KeyBinder 未加载";
        el.className = "hk-vk-status err";
      } else {
        el.textContent = "";
        el.className = "hk-vk-status";
      }
    }
    function readGeneral(d){
      const cp = document.getElementById("cursorPath");
      if (cp) d.cursorPath = cp.value.trim();
      const ht = document.getElementById("holdTime");
      if (ht) d.capslockHoldTimeSeconds = Number(ht.value);
      const as = document.getElementById("autoStart");
      if (as) d.autoStart = !!as.checked;
      const dst = document.getElementById("defaultStartTab");
      if (dst && defaultStartTabDirty) d.defaultStartTab = dst.value;
      return d;
    }
    function readAppearance(d){
      const pick = (id, fn) => {
        const el = document.getElementById(id);
        if (el) fn(el);
      };
      pick("themeMode", (el) => { d.themeMode = el.value; });
      pick("popupScreenIndex", (el) => { d.popupScreenIndex = Number(el.value); });
      pick("holePositionMode", (el) => { d.holePositionMode = el.value; });
      pick("holeTriggerDistance", (el) => { d.holeTriggerDistance = Number(el.value); });
      pick("holeDismissDistance", (el) => { d.holeDismissDistance = Number(el.value); });
      pick("holeFixedX", (el) => { d.holeFixedX = Number(el.value); });
      pick("holeFixedY", (el) => { d.holeFixedY = Number(el.value); });
      pick("holeSizeScale", (el) => { d.holeSizeScale = Number(el.value); });
      pick("holeAnimLevel", (el) => { d.holeAnimLevel = Number(el.value); });
      pick("holeVisualStyle", (el) => { d.holeVisualStyle = el.value; });
      pick("holeHideDockEnabled", (el) => { d.holeHideDockEnabled = !!el.checked; });
      pick("holeHideDockEdge", (el) => { d.holeHideDockEdge = el.value; });
      pick("holeHideDockMargin", (el) => { d.holeHideDockMargin = Number(el.value); });
      pick("holeTriggerTextSelect", (el) => { d.holeTriggerTextSelect = !!el.checked; });
      pick("holeTriggerCircleCw", (el) => { d.holeTriggerCircleCw = !!el.checked; });
      pick("holeTriggerCircleCcw", (el) => { d.holeTriggerCircleCcw = !!el.checked; });
      pick("holeTriggerRButtonHold", (el) => { d.holeTriggerRButtonHold = !!el.checked; });
      pick("holeRButtonHoldMs", (el) => { d.holeRButtonHoldMs = normalizeHoleRButtonHoldMs(el.value); });
      pick("holeSensitivityPreset", (el) => { d.holeSensitivityPreset = el.value; });
      pick("holePlacementPreset", (el) => { d.holePlacementPreset = el.value; });
      return d;
    }
    function captureAppearanceTabState() {
      const d = syncHoleDerivedFields(readAppearance({ ...state.data }));
      const ps = document.getElementById("popupScreenIndex");
      if (ps) d.popupScreenIndex = Number(ps.value);
      state.data = d;
      return state.data;
    }
    function postSavePopupScreen() {
      captureAppearanceTabState();
      const idx = Number(state.data.popupScreenIndex) || 1;
      post({ type: "savePopupScreenIndex", popupScreenIndex: idx });
    }
    function validateHoleTriggers(d) {
      if (d.holeTriggerTextSelect || d.holeTriggerCircleCw || d.holeTriggerCircleCcw || d.holeTriggerRButtonHold) return "";
      return "请至少启用一种黑洞触发方式";
    }
    function validateHoleSettingsOnly(d) {
      const trigErr = validateHoleTriggers(d);
      if (trigErr) return trigErr;
      if (![1000, 3000, 5000].includes(normalizeHoleRButtonHoldMs(d.holeRButtonHoldMs))) return "长按右键时长非法";
      if (!["cursor","fixed","edge"].includes(String(d.holePlacementPreset || "cursor"))) return "黑洞出现位置非法";
      if (!["compact","standard","relaxed"].includes(String(d.holeSensitivityPreset || "standard"))) return "接近灵敏度非法";
      if (!["ring","starry"].includes(String(d.holeVisualStyle || "ring"))) return "黑洞样式非法";
      const ss = Number(d.holeSizeScale);
      if (!Number.isFinite(ss) || ss < 0.85 || ss > 1.5) return "黑洞大小非法";
      return "";
    }
    const HOLE_SENSITIVITY_DIST = { compact: [200, 260], standard: [260, 320], relaxed: [340, 420] };
    const HOLE_RBUTTON_HOLD_MS_OPTS = [
      { value: "1000", label: "1 秒" },
      { value: "3000", label: "3 秒（推荐）" },
      { value: "5000", label: "5 秒" }
    ];
    function normalizeHoleRButtonHoldMs(ms) {
      const n = Number(ms);
      if (n <= 1500) return 1000;
      if (n <= 4000) return 3000;
      return 5000;
    }
    function syncHoleDerivedFields(d) {
      const sens = HOLE_SENSITIVITY_DIST[d.holeSensitivityPreset] || HOLE_SENSITIVITY_DIST.standard;
      d.holeTriggerDistance = sens[0];
      d.holeDismissDistance = sens[1];
      const place = String(d.holePlacementPreset || "cursor");
      if (place === "fixed") {
        d.holePositionMode = "fixed";
        d.holeHideDockEnabled = false;
      } else if (place === "edge") {
        d.holePositionMode = "anchor";
        d.holeHideDockEnabled = true;
        if (!d.holeHideDockEdge) d.holeHideDockEdge = "right";
      } else {
        d.holePositionMode = "anchor";
        d.holeHideDockEnabled = false;
      }
      const ss = Number(d.holeSizeScale);
      if (Number.isFinite(ss)) {
        if (ss <= 0.92) d.holeAnimLevel = 0.85;
        else if (ss >= 1.32) d.holeAnimLevel = 1.15;
        else d.holeAnimLevel = 1.0;
      } else {
        d.holeAnimLevel = 1.0;
      }
      if (!Number.isFinite(Number(d.holeHideDockMargin))) d.holeHideDockMargin = 10;
      return d;
    }
    const HOLE_SIZE_SCALE_LABELS = [
      [0.85, "小"], [0.95, "偏小"], [1.0, "标准"], [1.15, "偏大"], [1.25, "大"], [1.5, "超大"]
    ];
    function holeSizeScaleLabel(v) {
      const n = Number(v);
      if (!Number.isFinite(n)) return "标准";
      let best = HOLE_SIZE_SCALE_LABELS[2];
      let bestD = Math.abs(n - best[0]);
      for (const pair of HOLE_SIZE_SCALE_LABELS) {
        const d = Math.abs(n - pair[0]);
        if (d < bestD) { best = pair; bestD = d; }
      }
      return best[1];
    }
    function updateHoleStylePreview() {
      const stage = document.getElementById("holeStylePreview");
      const meta = document.getElementById("holePreviewMeta");
      if (!stage) return;
      const style = (document.getElementById("holeVisualStyle")?.value || "ring").toLowerCase();
      const scale = Math.max(0.85, Math.min(1.5, Number(document.getElementById("holeSizeScale")?.value || 1) || 1));
      const base = 72;
      const px = Math.round(base * scale);
      const sens = document.getElementById("holeSensitivityPreset")?.value || "standard";
      const place = document.getElementById("holePlacementPreset")?.value || "cursor";
      const sensMap = { compact: "紧凑", standard: "标准", relaxed: "宽松" };
      const placeMap = { cursor: "跟随光标", fixed: "固定坐标", edge: "贴边隐藏" };
      if (style === "starry") {
        stage.innerHTML = `<div class="hole-preview-starry" style="width:${px}px;height:${px}px;"></div>`;
      } else {
        stage.innerHTML = `<div class="hole-preview-ring" style="width:${px}px;height:${px}px;"><img src="${esc(NIUMA_ICON_URL)}" alt=""></div>`;
      }
      if (meta) {
        meta.textContent = `${style === "starry" ? "星空" : "彩环"} · ${holeSizeScaleLabel(scale)} · 接近${sensMap[sens] || "标准"} · ${placeMap[place] || ""}`;
      }
      const sizeLbl = document.getElementById("holeSizeScaleLabel");
      if (sizeLbl) sizeLbl.textContent = holeSizeScaleLabel(scale);
    }
    let holeSettingsSaveTimer = 0;
    function flushHoleSettingsSaveNow() {
      if (suppressAutoSave || !initDataReceived) return;
      if (holeSettingsSaveTimer) {
        clearTimeout(holeSettingsSaveTimer);
        holeSettingsSaveTimer = 0;
      }
      const d = syncHoleDerivedFields({ ...state.data });
      const err = validateHoleSettingsOnly(d);
      if (err) return setStatus(err, "err");
      post({ type: "saveHoleSettings", payload: collectHoleSettingsPayload(d) });
      setStatus("黑洞设置保存中...", "ok");
    }
    function scheduleHoleSettingsSave(delay = 400) {
      if (suppressAutoSave || !initDataReceived) return;
      if (holeSettingsSaveTimer) clearTimeout(holeSettingsSaveTimer);
      holeSettingsSaveTimer = setTimeout(() => {
        holeSettingsSaveTimer = 0;
        flushHoleSettingsSaveNow();
      }, delay);
    }
    function bindHoleSettingsUi() {
      const placeSel = document.getElementById("holePlacementPreset");
      const fixedRow = document.getElementById("holeFixedRow");
      const edgeRow = document.getElementById("holeEdgeRow");
      const rbtnRow = document.getElementById("holeRbtnRow");
      const rbtnChk = document.getElementById("holeTriggerRButtonHold");
      const syncPlacementRows = () => {
        const p = placeSel ? placeSel.value : "cursor";
        if (fixedRow) fixedRow.classList.toggle("visible", p === "fixed");
        if (edgeRow) edgeRow.classList.toggle("visible", p === "edge");
      };
      const syncRbtnRow = () => {
        if (rbtnRow) rbtnRow.classList.toggle("visible", !!(rbtnChk && rbtnChk.checked));
      };
      if (placeSel) placeSel.addEventListener("change", () => { syncPlacementRows(); updateHoleStylePreview(); });
      if (rbtnChk) rbtnChk.addEventListener("change", syncRbtnRow);
      syncPlacementRows();
      syncRbtnRow();
      document.querySelectorAll("#holeStyleChips .hole-chip").forEach((btn) => {
        btn.addEventListener("click", () => {
          const st = btn.getAttribute("data-hole-style") || "ring";
          const hid = document.getElementById("holeVisualStyle");
          if (hid) hid.value = st;
          document.querySelectorAll("#holeStyleChips .hole-chip").forEach((b) => b.classList.toggle("active", b === btn));
          updateHoleStylePreview();
          captureAppearanceTabState();
          scheduleHoleSettingsSave(500);
        });
      });
      const sizeEl = document.getElementById("holeSizeScale");
      if (sizeEl) {
        sizeEl.addEventListener("input", () => { updateHoleStylePreview(); });
      }
      updateHoleStylePreview();
      const holeSaveIds = ["holeTriggerTextSelect","holeTriggerCircleCw","holeTriggerCircleCcw","holeTriggerRButtonHold","holeRButtonHoldMs","holeSensitivityPreset","holePlacementPreset","holeFixedX","holeFixedY","holeHideDockEdge"];
      holeSaveIds.forEach((id) => {
        const el = document.getElementById(id);
        if (!el) return;
        const onHoleFieldChange = () => {
          if (id === "holePlacementPreset") syncPlacementRows();
          if (id === "holeTriggerRButtonHold") syncRbtnRow();
          updateHoleStylePreview();
          captureAppearanceTabState();
          scheduleHoleSettingsSave(500);
        };
        el.addEventListener("change", onHoleFieldChange);
        if (el.type === "number" || el.type === "range") el.addEventListener("input", onHoleFieldChange);
      });
      if (sizeEl) {
        sizeEl.addEventListener("change", () => {
          captureAppearanceTabState();
          scheduleHoleSettingsSave(500);
        });
      }
      const previewBtn = document.getElementById("btnPreviewHoleOnScreen");
      if (previewBtn) {
        previewBtn.addEventListener("click", () => {
          const d = syncHoleDerivedFields(readFromUI());
          const err = validateHoleSettingsOnly(d);
          if (err) return setStatus(err, "err");
          post({ type: "previewHoleOnScreen", payload: collectHoleSettingsPayload(d) });
          setStatus("正在屏幕上预览黑洞…", "ok");
        });
      }
    }
    function collectHoleSettingsPayload(d) {
      d = syncHoleDerivedFields({ ...d });
      return {
        holeTriggerTextSelect: d.holeTriggerTextSelect,
        holeTriggerCircleCw: d.holeTriggerCircleCw,
        holeTriggerCircleCcw: d.holeTriggerCircleCcw,
        holeTriggerRButtonHold: d.holeTriggerRButtonHold,
        holeRButtonHoldMs: d.holeRButtonHoldMs,
        holeSensitivityPreset: d.holeSensitivityPreset,
        holePlacementPreset: d.holePlacementPreset,
        holePositionMode: d.holePositionMode,
        holeTriggerDistance: d.holeTriggerDistance,
        holeDismissDistance: d.holeDismissDistance,
        holeFixedX: d.holeFixedX,
        holeFixedY: d.holeFixedY,
        holeSizeScale: d.holeSizeScale,
        holeAnimLevel: d.holeAnimLevel,
        holeVisualStyle: d.holeVisualStyle,
        holeHideDockEnabled: d.holeHideDockEnabled,
        holeHideDockEdge: d.holeHideDockEdge,
        holeHideDockMargin: d.holeHideDockMargin
      };
    }
    function readPrompts(d){
      const cr = { ...(d.cursorRules || {}) };
      const ruleEl = document.getElementById("cursorRuleContent");
      if (ruleEl) cr[state.cursorRulesTab] = ruleEl.value ?? "";
      d.cursorRules = cr;
      return d;
    }
    function formatAhkShortcut(raw) {
      const s = String(raw || "").trim();
      if (!s) return "—";
      if (/[⌃⌥⇧]/.test(s)) {
        return s
          .replace(/⌃⇧\+?/gi, "Ctrl+Shift+")
          .replace(/⌃⌥\+?/gi, "Ctrl+Alt+")
          .replace(/⌃\+?/gi, "Ctrl+")
          .replace(/⌥\+?/gi, "Alt+")
          .replace(/⇧\+?/gi, "Shift+")
          .replace(/\s+\+\s*$/g, "")
          .trim() || "—";
      }
      if (s.startsWith("seq:")) {
        const body = s.slice(4);
        const sep = body.indexOf("||");
        if (sep > 0) {
          const k1 = body.slice(0, sep);
          const k2 = body.slice(sep + 2);
          const d1 = formatAhkShortcut(k1);
          const d2 = formatAhkShortcut(k2);
          if (k1 === k2) return d1 + " twice";
          return d1 + " then " + d2;
        }
      }
      if (s === "^^") return "Double Ctrl";
      if (s === "++") return "Double Shift";
      if (s === "!!") return "Double Alt";
      if (/^(Ctrl|Alt|Shift|Win|CapsLock|Double )/i.test(s) && !/[\^!+#]/.test(s)) return s;
      let display = "";
      let key = s;
      if (key.includes("^")) {
        display += "Ctrl+";
        key = key.replace(/\^/g, "");
      }
      if (key.includes("!")) {
        display += "Alt+";
        key = key.replace(/!/g, "");
      }
      if (key.includes("+")) {
        display += "Shift+";
        key = key.replace(/\+/g, "");
      }
      if (key.includes("#")) {
        display += "Win+";
        key = key.replace(/#/g, "");
      }
      if (key === "``") key = "`";
      else if (key.length === 1 && /^[a-z]$/i.test(key)) key = key.toUpperCase();
      const special = {
        Escape: "Esc", Enter: "Enter", Space: "Space", Tab: "Tab",
        Backspace: "Bks", Delete: "Del", Insert: "Ins",
        Home: "Home", End: "End", PgUp: "PgUp", PgDn: "PgDn",
        Up: "↑", Down: "↓", Left: "←", Right: "→",
        LShift: "LShift", RShift: "RShift", LCtrl: "LCtrl", RCtrl: "RCtrl",
        LAlt: "LAlt", RAlt: "RAlt", LWin: "Win", RWin: "Win", AppsKey: "Menu",
        PrintScreen: "PrtSc", ScrollLock: "ScrLk", Pause: "Pause",
        Comma: ",", Period: "."
      };
      if (special[key]) key = special[key];
      return (display + key) || "—";
    }
    function renderCursorShortcutRefRows(list) {
      const rows = Array.isArray(list) ? list : [];
      if (!rows.length) {
        return `<div class="hint">未加载 Cursor 快捷键，请重新打开设置页。</div>`;
      }
      return `<div class="shortcut-ref-list">${rows.map((row) => {
        const label = esc(row.label || row.id || "—");
        const combo = esc(formatAhkShortcut(row.shortcut || ""));
        const desc = esc(row.desc || "");
        return `<div class="shortcut-ref-row">
  <div><div class="shortcut-ref-kbd">${combo}</div></div>
  <div><div class="shortcut-ref-label">${label}</div>${desc ? `<div class="shortcut-ref-desc">${desc}</div>` : ""}</div>
</div>`;
      }).join("")}</div>`;
    }
    function renderAppShortcutRefRows() {
      return `<div class="shortcut-ref-list">${APP_SHORTCUT_REFERENCE.map((row) => `
<div class="shortcut-ref-row">
  <div><div class="shortcut-ref-kbd">${esc(row.combo)}</div></div>
  <div><div class="shortcut-ref-label">${esc(row.label)}</div><div class="shortcut-ref-desc">${esc(row.desc)}</div></div>
</div>`).join("")}</div>`;
    }
    function mergeKeybinderBindingsFromHost(bindings, suggested) {
      if (bindings && typeof bindings === "object" && !Array.isArray(bindings))
        state.data.keybinderBindings = { ...bindings };
      if (suggested && typeof suggested === "object" && !Array.isArray(suggested))
        state.data.keybinderSuggestedBindings = { ...suggested };
    }
    function mergeCursorShortcutsAsSuggested(list) {
      const rows = Array.isArray(list) ? list : [];
      if (!rows.length) return;
      const sug = { ...(state.data.keybinderSuggestedBindings || {}) };
      let changed = false;
      rows.forEach((row) => {
        const id = String(row?.vkCommandId || "").trim();
        const sk = String(row?.shortcut || "").trim();
        if (!id || !sk || sug[id]) return;
        sug[id] = sk;
        changed = true;
      });
      if (changed) state.data.keybinderSuggestedBindings = sug;
    }
    function getVkBindingEntry(cmdId) {
      const b = state.data.keybinderBindings || {};
      return b[cmdId] || null;
    }
    function getVkSuggestedKey(cmdId) {
      const s = state.data.keybinderSuggestedBindings || {};
      const v = s[cmdId];
      return v != null ? String(v) : "";
    }
    function hkIsUnmodifiedAhkKey(ahkKey) {
      const s = String(ahkKey || "").trim();
      if (!s || s === "^^" || s === "++" || s === "!!") return false;
      return !(/[\^!+#+]/.test(s));
    }
    function hkShouldCapsChord(cmdId, ahkKey) {
      const id = String(cmdId || "");
      if (id.startsWith("ch_")) return hkIsUnmodifiedAhkKey(ahkKey);
      if (id.startsWith("qa_") || id.startsWith("sc_") || id.startsWith("cp_")) return false;
      return hkIsUnmodifiedAhkKey(ahkKey);
    }
    function displayKeyForSettingsCmd(cmdId) {
      const ent = getVkBindingEntry(cmdId);
      if (ent && ent.explicitNone) return "—";
      if (ent && ent.ahkKey) {
        const t = ent.displayKey || formatAhkShortcut(ent.ahkKey);
        return t || "—";
      }
      const sug = getVkSuggestedKey(cmdId);
      if (sug) {
        const raw = formatAhkShortcut(sug);
        return raw || "—";
      }
      return "—";
    }
    function renderVkCmdRowHtml(cmdId, cmd) {
      const id = String(cmdId || "").trim();
      if (!id) return "";
      const c = cmd || buildKeybinderCommandMap()[id] || { name: id, desc: "" };
      const ent = getVkBindingEntry(id);
      const isNone = !!(ent && ent.explicitNone);
      const hasReal = !!(ent && ent.ahkKey);
      const hasSuggested = !!getVkSuggestedKey(id) && !hasReal && !isNone;
      const isRec = state.hkRecording === id;
      let rowCls = "cmd-row";
      if (hasReal || hasSuggested) rowCls += " has-binding";
      if (isRec) rowCls += " recording active-focus";
      if (hasReal) rowCls += " binding-custom";
      else if (hasSuggested) rowCls += " binding-suggested";
      else if (isNone) rowCls += " binding-none";
      const iconSvg = cfgToolbarIconSvg(id, c.iconClass || "");
      const title = esc(c.name || id);
      const desc = String(c.desc || "").trim();
      const keyHtml = isRec
        ? '<span class="hk-rec-pulse">录制中：按下快捷键（连按两次可录制序列）…</span>'
        : esc(displayKeyForSettingsCmd(id));
      const showClr = !isRec && (hasReal || hasSuggested);
      const showRst = !isRec && hasReal;
      return `<div class="${rowCls}" data-vk-cmd="${esc(id)}"${desc ? ` title="${esc(desc)}"` : ""}>
  <div class="cmd-name">
    <span class="cmd-icon">${iconSvg}</span>
    <span class="cmd-title">${title}</span>
  </div>
  <div class="cmd-key">${keyHtml}</div>
  <div class="cmd-actions">
    <button type="button" class="btn-icon hk-vk-rec${isRec ? " active-rec" : ""}" data-vk-rec="${esc(id)}" title="${isRec ? "停止录制" : "录制快捷键"}">${isRec ? '<i class="fa-solid fa-stop" aria-hidden="true"></i>' : '<i class="fa-solid fa-play" aria-hidden="true"></i>'}</button>
    <button type="button" class="btn-icon danger hk-vk-clr" data-vk-clr="${esc(id)}" title="清空按键（显式禁用）"${showClr ? "" : ' style="display:none"'}><i class="fa-solid fa-eraser" aria-hidden="true"></i></button>
    <button type="button" class="btn-icon hk-vk-rst" data-vk-rst="${esc(id)}" title="重置为建议值"${showRst ? "" : ' style="display:none"'}><i class="fa-solid fa-arrow-rotate-left" aria-hidden="true"></i></button>
  </div>
</div>`;
    }
    function renderVkCmdListHtml(cmdIds, searchKw) {
      const kw = String(searchKw || "").trim().toLowerCase();
      const cmdMap = buildKeybinderCommandMap();
      const ids = (Array.isArray(cmdIds) ? cmdIds : []).filter((id) => {
        const c = cmdMap[id] || { id, name: id, desc: "" };
        if (!kw) return true;
        const blob = `${id} ${c.name || ""} ${c.desc || ""}`.toLowerCase();
        return blob.includes(kw);
      });
      if (!ids.length) return `<div class="hk-no-command">[NO COMMAND FOUND]</div>`;
      return ids.map((id) => renderVkCmdRowHtml(id, cmdMap[id] || { id, name: id, desc: "" })).join("");
    }
    function renderCursorVkCmdListHtml(list, searchKw) {
      const rows = Array.isArray(list) ? list : [];
      const kw = String(searchKw || "").trim().toLowerCase();
      const filtered = rows.filter((row) => {
        if (!kw) return true;
        const blob = `${row.label || ""} ${row.desc || ""} ${row.vkCommandId || ""}`.toLowerCase();
        return blob.includes(kw);
      });
      if (!filtered.length) return `<div class="hk-no-command">[NO COMMAND FOUND]</div>`;
      return filtered.map((row) => {
        const cmdId = String(row.vkCommandId || "").trim();
        if (!cmdId) {
          const combo = esc(formatAhkShortcut(row.shortcut || ""));
          const desc = esc(row.desc || "");
          return `<div class="cmd-row binding-suggested has-binding"${desc ? ` title="${desc}"` : ""}>
  <div class="cmd-name"><span class="cmd-icon">${cfgToolbarIconSvg("", "fa-keyboard")}</span><span class="cmd-title">${esc(row.label || "—")}</span></div>
  <div class="cmd-key">${combo}</div><div class="cmd-actions"></div></div>`;
        }
        const cmd = buildKeybinderCommandMap()[cmdId] || { name: row.label, desc: row.desc };
        return renderVkCmdRowHtml(cmdId, cmd);
      }).join("");
    }
    function isCapsLockLayerEnabled(d) {
      return String(d?.capsLockMode || "chord") !== "off";
    }
    function capsLockHoldHintSeconds(d) {
      const capsHold = Number(d?.capslockHoldTimeSeconds);
      return Number.isFinite(capsHold) ? capsHold.toFixed(1) : "0.5";
    }
    function capsLockLayerHintHtml(enabled, holdHint) {
      if (!enabled) {
        return `和弦层已关闭。<strong>双击 CapsLock</strong> 仍可打开命令面板；按住+字母、长按键帽提示已停用。`;
      }
      return `<strong>按住</strong> + 字母 → 牛马命令 · <strong>长按 ${esc(holdHint)} 秒</strong> → 键帽提示 · <strong>双击</strong> → 命令面板`;
    }
    function syncCapsLockLayerToggleDom(enabled, holdHint) {
      const btn = document.getElementById("btnCapsLockLayerToggle");
      const hint = document.getElementById("capsLockLayerHint");
      if (btn) {
        btn.classList.toggle("is-on", !!enabled);
        btn.setAttribute("aria-pressed", enabled ? "true" : "false");
        const st = btn.querySelector(".hk-capslit-state");
        if (st) st.textContent = enabled ? "已点亮" : "已熄灭";
      }
      if (hint) hint.innerHTML = capsLockLayerHintHtml(!!enabled, holdHint);
    }
    function readCapsLockLayerEnabledFromDom() {
      const btn = document.getElementById("btnCapsLockLayerToggle");
      if (!btn) return isCapsLockLayerEnabled(state.data);
      return btn.classList.contains("is-on");
    }
    function renderSummonConflictCard(d) {
      const holdHint = capsLockHoldHintSeconds(d);
      const layerOn = isCapsLockLayerEnabled(d);
      return `<div class="card hk-summon-card" style="margin-bottom:12px">
  <div class="title">CapsLock 和弦层</div>
  <div class="hk-capslit-row">
    <button type="button" id="btnCapsLockLayerToggle" class="hk-capslit-btn${layerOn ? " is-on" : ""}" aria-pressed="${layerOn ? "true" : "false"}" title="点击点亮/熄灭 CapsLock 和弦层">
      <span class="hk-capslit-led" aria-hidden="true"></span>
      <span class="hk-capslit-key">CapsLock</span>
      <span class="hk-capslit-state">${layerOn ? "已点亮" : "已熄灭"}</span>
    </button>
    <div id="capsLockLayerHint" class="hk-capslit-hint">${capsLockLayerHintHtml(layerOn, holdHint)}</div>
  </div>
  <label class="hk-summon-check-row subtle"><input id="hotkeyForceRevealAll" type="checkbox" ${checked(!!d.hotkeyForceRevealAll)}> 跳过引导，一次显示全部快捷键</label>
</div>`;
    }
    async function showHotkeyConflictConfirm(title, detail, opts) {
      const o = opts || {};
      if (window.nmConfirm) {
        return window.nmConfirm(title, detail, {
          okLabel: o.okLabel || "确定",
          cancelLabel: o.cancelLabel || "取消",
          danger: !!o.danger
        });
      }
      return Promise.resolve(confirm(`${title}\n${detail || ""}`));
    }
    function readSummonFieldsFromDom(d) {
      d.summonHotkeyPreset = "capslock";
      d.summonHotkeyCustom = "";
      const layerOn = readCapsLockLayerEnabledFromDom();
      d.capsLockMode = layerOn ? "chord" : "off";
      d.capsLockHoldVkEnabled = layerOn;
      const forceEl = document.getElementById("hotkeyForceRevealAll");
      if (forceEl) d.hotkeyForceRevealAll = !!forceEl.checked;
      return d;
    }
    function renderHotkeysSubTabHtml(d, subId) {
      const capsHold = Number(d.capslockHoldTimeSeconds);
      const capsHoldHint = Number.isFinite(capsHold) ? capsHold.toFixed(1) : "0.5";
      const cursorList = (Array.isArray(d.cursorShortcuts) && d.cursorShortcuts.length) ? d.cursorShortcuts : DEFAULT_CURSOR_SHORTCUTS;
      const appShortcutRows = renderAppShortcutRefRows();
      const bindListBlock = (listId, innerHtml) => `
<div class="hk-bind-zone">
  <div class="hk-cmd-search-bar">
    <input type="text" class="hk-cmd-search" data-hk-search-for="${esc(listId)}" placeholder="搜索命令..." value="${esc(state.hkCmdSearch)}" autocomplete="off" spellcheck="false">
    <span class="hk-cmd-count" id="${esc(listId)}-count">0 个命令</span>
  </div>
  <div class="hk-cmd-list-wrapper">
    <div class="hk-cmd-list" id="${esc(listId)}">${innerHtml}</div>
  </div>
</div>`;
      if (subId === "overview") {
        return `${renderSummonConflictCard(d)}
${appShortcutRows}
<div class="row" style="margin-top:12px"><div class="label">Prompt 快速采集</div><input id="promptQuickCaptureHotkey" type="text" value="${esc(d.promptQuickCaptureHotkey)}" placeholder="如 ^!p，留空不注册"></div>
<div class="hk-open-vk-row"><button type="button" class="btn primary" id="btnOpenVkKeybinder"><i class="fa-solid fa-keyboard" aria-hidden="true"></i> 打开 VK KeyBinder</button><span id="hk-vk-status" class="hk-vk-status"></span></div>`;
      }
      if (subId === "cursor") {
        return `<div class="hk-note" style="padding:0;margin-bottom:8px">组合键同步至 KeyBinder 与 Cursor 映射；点 <i class="fa-solid fa-play"></i> 录制，Esc 取消。</div>
${bindListBlock("hk-cursor-list", renderCursorVkCmdListHtml(cursorList, state.hkCmdSearch))}`;
      }
      const preset = HK_VK_PRESETS.find((p) => p.id === subId);
      if (preset) {
        return `<div class="hk-note" style="padding:0;margin-bottom:8px">${esc(preset.name)} · 与 VK「快捷键」场景一致；录制冲突时可选「改绑」覆盖原命令。</div>
${bindListBlock("hk-vk-list-" + subId, renderVkCmdListHtml(preset.commands, state.hkCmdSearch))}`;
      }
      if (subId === "toolbar") {
        return `<div class="hk-note">拖拽调整悬浮栏按钮顺序；松手后自动写入 Commands.json 并刷新工具栏。</div>
<div class="advanced-workbench-row">
  <div class="card ftb-workbench-card" style="margin:0">
    <div class="title">悬浮栏按钮</div>
    <div class="ftb-mock-strip">
      <div class="ftb-mock-logo" aria-hidden="true"></div>
      <div class="ftb-mock-btns" id="cfg-ftb-bar"></div>
    </div>
    <div class="ftb-pool-hint">未上栏的命令（拖到上方条带即可显示）</div>
    <div class="ftb-mock-pool" id="cfg-shared-pool-ftb"></div>
  </div>
  <div class="card menu-workbench-card" style="margin:0">
    <div class="title">工具栏右键菜单</div>
    <div class="cfg-menu-mock-popup">
      <div class="cfg-menu-bar" id="cfg-menu-bar-cmds"></div>
    </div>
    <div class="ftb-pool-hint">可用命令池（拖到菜单条）</div>
    <div class="cfg-menu-pool" id="cfg-shared-pool-menu-cmds"></div>
  </div>
</div>`;
      }
      return "";
    }
    function renderHkRecordHudText() {
      if (state.hkRecordHudText) return state.hkRecordHudText;
      const rec = state.hkRecording;
      if (!rec) return "";
      const cmd = buildKeybinderCommandMap()[rec];
      const name = (cmd && cmd.name) ? cmd.name : rec;
      return "MODE: CONFIG | 正在录制: " + name + " | 请按键（支持连按组成序列）";
    }
    function updateHkRecordHudDom() {
      const hud = document.getElementById("hk-record-hud");
      if (!hud) return;
      const text = renderHkRecordHudText();
      const rec = !!state.hkRecording;
      hud.textContent = text;
      hud.classList.toggle("visible", !!text);
      hud.classList.toggle("recording", rec);
    }
    function refreshHotkeyCmdRow(cmdId) {
      const id = String(cmdId || "").trim();
      if (!id) return;
      const row = document.querySelector(`.hk-bind-zone .cmd-row[data-vk-cmd="${CSS.escape(id)}"]`);
      if (!row) return;
      const cmd = buildKeybinderCommandMap()[id];
      row.outerHTML = renderVkCmdRowHtml(id, cmd);
      bindHotkeysVkRowHandlers();
      updateHotkeyCmdListCounts();
    }
    function renderHotkeysTabShell(d) {
      const subTabs = HK_SUB_TABS.map((t) =>
        `<button type="button" class="vk-main-tab${state.hotkeysSubTab === t.id ? " active" : ""}" data-hk-sub="${esc(t.id)}">${esc(t.label)}</button>`
      ).join("");
      const panels = HK_SUB_TABS.map((t) =>
        `<div class="hk-sub-panel${state.hotkeysSubTab === t.id ? " active" : ""}" id="hk-panel-${esc(t.id)}">${renderHotkeysSubTabHtml(d, t.id)}</div>`
      ).join("");
      const hudText = renderHkRecordHudText();
      return `<div class="card hk-card">
  <div class="hk-card-head">
    <div class="title">快捷键</div>
    <div id="hk-record-hud" class="hk-record-hud${hudText ? " visible" : ""}${state.hkRecording ? " recording" : ""}">${esc(hudText)}</div>
  </div>
  <div class="vk-main-tabs hk-sub-tabs" role="tablist">${subTabs}</div>
  ${panels}
</div>`;
    }
    function updateHotkeyCmdListCounts() {
      document.querySelectorAll(".hk-cmd-list").forEach((list) => {
        const countEl = document.getElementById(list.id + "-count");
        if (countEl) countEl.textContent = list.querySelectorAll(".cmd-row").length + " 个命令";
      });
    }
    function stopHotkeyRecording() {
      if (!state.hkRecording) return;
      state.hkRecording = null;
      state.hkRecordHudText = "";
      post({ type: "vkCancelRecord" });
      updateHkRecordHudDom();
      document.querySelectorAll(".hk-bind-zone .cmd-row.recording").forEach((row) => {
        const id = row.getAttribute("data-vk-cmd");
        if (id) refreshHotkeyCmdRow(id);
      });
    }
    function startHotkeyRecording(cmdId) {
      const id = String(cmdId || "").trim();
      if (!id) return;
      if (state.hkRecording === id) {
        stopHotkeyRecording();
        return;
      }
      state.hkRecording = id;
      state.hkRecordHudText = "";
      post({ type: "vkStartRecord", commandId: id });
      if (state.activeTab === "hotkeys") {
        render();
      }
    }
    function bindHotkeysTabHandlers() {
      mergeCursorShortcutsAsSuggested(
        (Array.isArray(state.data.cursorShortcuts) && state.data.cursorShortcuts.length)
          ? state.data.cursorShortcuts : DEFAULT_CURSOR_SHORTCUTS
      );
      document.querySelectorAll("[data-hk-sub]").forEach((btn) => {
        btn.addEventListener("click", () => {
          stopHotkeyRecording();
          state.hkCmdSearch = "";
          state.hotkeysSubTab = btn.getAttribute("data-hk-sub");
          render();
        });
      });
      document.querySelectorAll(".hk-cmd-search").forEach((inp) => {
        inp.addEventListener("input", () => {
          state.hkCmdSearch = inp.value || "";
          const forId = inp.getAttribute("data-hk-search-for");
          const list = forId ? document.getElementById(forId) : null;
          if (!list) return;
          const preset = HK_VK_PRESETS.find((p) => list.id === "hk-vk-list-" + p.id);
          if (state.hotkeysSubTab === "cursor") {
            const cursorList = (Array.isArray(state.data.cursorShortcuts) && state.data.cursorShortcuts.length)
              ? state.data.cursorShortcuts : DEFAULT_CURSOR_SHORTCUTS;
            list.innerHTML = renderCursorVkCmdListHtml(cursorList, state.hkCmdSearch);
          } else if (preset) {
            list.innerHTML = renderVkCmdListHtml(preset.commands, state.hkCmdSearch);
          }
          bindHotkeysVkRowHandlers();
          updateHotkeyCmdListCounts();
        });
      });
      bindHotkeysVkRowHandlers();
      const elPqc = document.getElementById("promptQuickCaptureHotkey");
      if (elPqc) {
        elPqc.addEventListener("input", () => scheduleSettingsPersist(false));
        elPqc.addEventListener("change", () => scheduleSettingsPersist(false));
      }
      document.getElementById("btnOpenVkKeybinder")?.addEventListener("click", () => post({ type: "invokeAction", op: "showVk" }));
      document.getElementById("btnCapsLockLayerToggle")?.addEventListener("click", () => {
        const enabled = readCapsLockLayerEnabledFromDom();
        const next = !enabled;
        syncCapsLockLayerToggleDom(next, capsLockHoldHintSeconds(state.data));
        state.data.capsLockMode = next ? "chord" : "off";
        state.data.capsLockHoldVkEnabled = next;
        scheduleSettingsPersist(false);
        setStatus(next ? "CapsLock 和弦层已点亮" : "CapsLock 和弦层已熄灭（双击仍可开命令面板）", next ? "ok" : "");
      });
      document.getElementById("hotkeyForceRevealAll")?.addEventListener("change", () => scheduleSettingsPersist(false));
      post({ type: "probeVk" });
      requestKeybinderCatalogIfNeeded();
      if (state.hotkeysSubTab === "toolbar") {
        mountFtbWorkbench();
        mountMenuWorkbench();
      }
      updateHotkeyCmdListCounts();
    }
    function bindHotkeysVkRowHandlers() {
      document.querySelectorAll("[data-vk-rec]").forEach((btn) => {
        btn.addEventListener("click", (e) => {
          e.stopPropagation();
          startHotkeyRecording(btn.getAttribute("data-vk-rec"));
        });
      });
      document.querySelectorAll("[data-vk-clr]").forEach((btn) => {
        btn.addEventListener("click", (e) => {
          e.stopPropagation();
          const id = btn.getAttribute("data-vk-clr");
          stopHotkeyRecording();
          post({ type: "vkClearBinding", commandId: id });
        });
      });
      document.querySelectorAll("[data-vk-rst]").forEach((btn) => {
        btn.addEventListener("click", (e) => {
          e.stopPropagation();
          const id = btn.getAttribute("data-vk-rst");
          stopHotkeyRecording();
          post({ type: "vkResetBinding", commandId: id });
        });
      });
    }
    function handleVkWebEvent(evt) {
      if (!evt || !evt.type) return;
      if (evt.type === "recordHint") {
        if (evt.active && evt.commandId) state.hkRecording = String(evt.commandId);
        else state.hkRecording = null;
        if (!evt.active) state.hkRecordHudText = "";
        if (state.activeTab === "hotkeys") {
          updateHkRecordHudDom();
          if (!evt.active) {
            document.querySelectorAll(".hk-bind-zone .cmd-row.recording").forEach((row) => {
              const id = row.getAttribute("data-vk-cmd");
              if (id) refreshHotkeyCmdRow(id);
            });
          } else {
            render();
          }
        }
        return;
      }
      if (evt.type === "recordPending") {
        const d = (evt.displayKey != null && evt.displayKey !== "") ? String(evt.displayKey) : "（键）";
        const w = typeof evt.waitMs === "number" ? evt.waitMs : 400;
        const sec = (w / 1000).toFixed(1).replace(/\.0$/, "");
        if (evt.kind === "dblMod")
          state.hkRecordHudText = "录制：" + d + " · 正在保存绑定…";
        else
          state.hkRecordHudText = "录制：已收到 「" + d + "」 · 约 " + sec + " 秒内可再按一键组成序列，否则保存为单键";
        if (state.activeTab === "hotkeys") updateHkRecordHudDom();
        return;
      }
      if (evt.type === "bindingUpdated") {
        const cmdId = String(evt.commandId || "");
        const bindings = { ...(state.data.keybinderBindings || {}) };
        if (evt.deleted) {
          delete bindings[cmdId];
        } else if (evt.explicitNone) {
          bindings[cmdId] = { ahkKey: "", displayKey: "", explicitNone: true };
        } else {
          bindings[cmdId] = {
            ahkKey: String(evt.ahkKey || ""),
            displayKey: String(evt.displayKey || evt.ahkKey || "")
          };
        }
        state.data.keybinderBindings = bindings;
        state.hkRecording = null;
        state.hkRecordHudText = "";
        if (state.activeTab === "hotkeys") {
          updateHkRecordHudDom();
          if (cmdId) refreshHotkeyCmdRow(cmdId);
          else render();
        }
        return;
      }
      if (evt.type === "confirmConflict") {
        const dk = evt.displayKey || evt.ahkKey || "";
        const other = evt.conflictCmdName || evt.conflictCmdId || "其他命令";
        const ask = showHotkeyConflictConfirm(
          "快捷键冲突",
          `「${dk}」已被「${other}」占用（可在「全局导航」等子页查看）。是否改绑到当前命令？`,
          { okLabel: "改绑", cancelLabel: "取消", danger: true }
        );
        ask.then((ok) => {
          post({
            type: "vkResolveConflict",
            confirm: !!ok,
            commandId: evt.commandId,
            ahkKey: evt.ahkKey,
            displayKey: evt.displayKey
          });
        });
        return;
      }
      if (evt.type === "bind_blocked") {
        setStatus("该键已被占用，无法绑定", "err");
        state.hkRecording = null;
        state.hkRecordHudText = "";
        if (state.activeTab === "hotkeys") {
          updateHkRecordHudDom();
          render();
        }
      }
    }
    function readHotkeys(d) {
      d.promptQuickCaptureHotkey = document.getElementById("promptQuickCaptureHotkey")?.value.trim() ?? d.promptQuickCaptureHotkey;
      return readSummonFieldsFromDom(d);
    }
    function readAdvanced(d){
      const lang = document.getElementById("language");
      if (lang) d.language = lang.value;
      const aiSec = document.getElementById("aiSleepTimeSeconds");
      if (aiSec) {
        const aiSleepSeconds = Number(aiSec.value);
        if (Number.isFinite(aiSleepSeconds)) d.aiSleepTime = Math.max(50, aiSleepSeconds * 1000);
      }
      const ld = document.getElementById("launchDelaySeconds");
      if (ld) {
        const v = Number(ld.value);
        if (Number.isFinite(v)) d.launchDelaySeconds = v;
      }
      const listValues = (id) => Array.from(document.getElementById(id)?.options || []).map(o => o.value).filter(Boolean);
      if (document.getElementById("toolbarButtonsList")) {
        const btns = listValues("toolbarButtonsList");
        d.floatingToolbarButtons = btns.length ? btns : [...DEFAULT_TOOLBAR_BUTTONS];
      }
      if (document.getElementById("toolbarMenusList")) {
        const menus = listValues("toolbarMenusList");
        d.floatingToolbarMenuItems = menus.length ? menus : [...DEFAULT_TOOLBAR_MENUS];
      }
      return d;
    }
    /** 与 Niuma Chat 服务商一致，便于用户按熟悉的名字填写 Key */
    const STUDIO_LLM_PRESETS = {
      openai: {
        label: "OpenAI",
        baseUrl: "https://api.openai.com/v1",
        model: "gpt-4o-mini",
        models: ["gpt-4o-mini", "gpt-4o", "gpt-4.1-mini", "gpt-4.1", "gpt-5.4-mini", "gpt-5.4", "gpt-5.4-nano", "gpt-5-chat-latest"],
        keyPh: "sk-…",
        hint: "OpenAI 官方 API；默认推荐 gpt-4o-mini（配额较稳）。若测试报 HTTP 429 多为限流，请间隔 30～60 秒再测，勿连续切换模型后连点「测试 API」。"
      },
      minimax: {
        label: "MiniMax",
        baseUrl: "https://api.minimax.io/anthropic",
        model: "MiniMax-M2.7",
        models: [
          "MiniMax-M3",
          "MiniMax-M2.7",
          "MiniMax-M2.7-highspeed",
          "MiniMax-M2.5",
          "MiniMax-M2.5-highspeed",
          "MiniMax-M2.1",
          "MiniMax-M2.1-highspeed",
          "MiniMax-M2"
        ],
        keyPh: "Token Plan / Coding Plan Key（sk-cp-…）",
        hint: "Billing → Token Plan / Coding Plan 密钥（sk-cp- 开头，≠开放平台按量付费接口密钥）。优先使用 https://api.minimax.io/anthropic；若你明确购买的是国内资源，再切到 https://api.minimaxi.com/anthropic。"
      },
      gemini: {
        label: "Google Gemini",
        baseUrl: "https://generativelanguage.googleapis.com/v1beta",
        model: "gemini-2.5-flash",
        models: ["gemini-2.5-flash", "gemini-2.5-pro", "gemini-2.0-flash"],
        keyPh: "AIzaSy…（aistudio.google.com）",
        hint: "在 Google AI Studio → Get API key 复制，以 AIza 开头，不是 OpenAI 的 sk-"
      },
      deepseek: {
        label: "DeepSeek",
        baseUrl: "https://api.deepseek.com/v1",
        model: "deepseek-chat",
        models: ["deepseek-chat", "deepseek-reasoner"],
        keyPh: "DeepSeek API Key",
        hint: "DeepSeek 开放平台密钥"
      },
      kimi: {
        label: "Kimi（月之暗面）",
        baseUrl: "https://api.moonshot.cn/v1",
        model: "kimi-k2.6",
        models: ["kimi-k2.6", "moonshot-v1-8k", "kimi-k2-thinking", "kimi-k2.5", "kimi-k2-turbo-preview"],
        keyPh: "Moonshot API Key（sk-…）",
        hint: "国内 Key → https://api.moonshot.cn/v1（platform.moonshot.cn）；国际 Key → https://api.moonshot.ai/v1。kimi-k2.6 需账号已开通 K2 系列且有余额；若测试失败可先用 moonshot-v1-8k。"
      },
      claude: {
        label: "Claude（Anthropic）",
        baseUrl: "https://api.anthropic.com",
        model: "claude-3-5-sonnet-latest",
        models: ["claude-3-5-sonnet-latest", "claude-3-7-sonnet-latest", "claude-3-5-haiku-latest"],
        keyPh: "sk-ant-…",
        hint: "Anthropic 控制台 API Key"
      },
      qwen: {
        label: "通义千问 Qwen",
        baseUrl: "https://dashscope.aliyuncs.com/compatible-mode/v1",
        model: "qwen-plus",
        models: ["qwen-plus", "qwen-turbo", "qwen-max", "qwen3-coder-plus"],
        keyPh: "DashScope API Key",
        hint: "阿里云百炼 / DashScope"
      },
      glm: {
        label: "智谱 GLM",
        baseUrl: "https://open.bigmodel.cn/api/paas/v4",
        model: "glm-4-plus",
        models: ["glm-4-plus", "glm-4-air", "glm-4-flash"],
        keyPh: "BigModel API Key",
        hint: "智谱 BigModel 开放平台"
      },
      zhipu: {
        label: "智谱（Zhipu）",
        baseUrl: "https://open.bigmodel.cn/api/paas/v4",
        model: "glm-4-plus",
        models: ["glm-4-plus", "glm-4-air", "glm-4-flash"],
        keyPh: "智谱 API Key",
        hint: "可与 GLM 使用不同密钥，分槽保存"
      },
      siliconflow: {
        label: "硅基流动",
        baseUrl: "https://api.siliconflow.cn/v1",
        model: "Qwen/Qwen2.5-7B-Instruct",
        models: ["Qwen/Qwen2.5-7B-Instruct", "deepseek-ai/DeepSeek-V3", "THUDM/glm-4-9b-chat"],
        keyPh: "硅基流动 API Key",
        hint: "SiliconFlow 控制台"
      },
      ollama: {
        label: "Ollama（云端）",
        baseUrl: "http://127.0.0.1:11434/v1",
        model: "nemotron-3-super:cloud",
        models: ["nemotron-3-super:cloud"],
        keyPh: "可选，本地一般留空",
        hint: "本机 Ollama 服务 + :cloud 云模型（不占大内存）"
      },
      openclaw: {
        label: "OpenClaw Gateway",
        baseUrl: "http://127.0.0.1:18789",
        model: "gateway",
        models: ["gateway"],
        keyPh: "Gateway Token（推荐点一键连接）",
        hint: "本机 Gateway · 非 sk- 云 API · 默认 127.0.0.1:18789"
      },
      hermes: {
        label: "Hermes Agent",
        baseUrl: "http://127.0.0.1:8642/v1",
        model: "hermes-agent",
        models: ["hermes-agent"],
        keyPh: "API Server Key（推荐点一键连接）",
        hint: "本机 Hermes OpenAI 兼容 API · 点「测试连接」会自动写入 .env 并开启 API Server（无需手改），重启 Hermes 后即可用"
      },
      custom: {
        label: "自定义（中转 / 私有网关）",
        baseUrl: "",
        model: "",
        models: [],
        keyPh: "Bearer Token",
        hint: "自行填写 Base URL 与模型名（OpenAI 兼容中转等）"
      }
    };

    function normalizeStudioLlmProvider(pid) {
      pid = String(pid || "").trim();
      if (pid === "anthropic") return "claude";
      if (pid === "codex") return "openai";
      return STUDIO_LLM_PRESETS[pid] ? pid : "openai";
    }

    function studioLlmPreset(pid) {
      return STUDIO_LLM_PRESETS[normalizeStudioLlmProvider(pid)] || STUDIO_LLM_PRESETS.openai;
    }

    const LLM_UNIFIED_CLOUD_VENDORS = [
      "openai", "deepseek", "kimi", "claude", "minimax", "qwen", "glm", "zhipu", "siliconflow", "gemini", "custom"
    ];

    function isLlmManagerEnabled() {
      const opt = state.data.userStudio?.options || {};
      if (opt.llmManagerEnabled === false) return false;
      const chk = document.getElementById("usLlmManagerEnabled");
      if (chk) return !!chk.checked;
      const u = state.data.userStudio?.llmUnified || {};
      if (u.managerEnabled === false) return false;
      return true;
    }

    function readLlmManagerEnabledFromOptions() {
      const opt = state.data.userStudio?.options || {};
      if (opt.llmManagerEnabled === false) return false;
      if (opt.llmManagerEnabled === true) return true;
      return true;
    }

    function readLlmManagerEnabledFromDom() {
      const el = document.getElementById("usLlmManagerEnabled");
      if (el) return !!el.checked;
      return readLlmManagerEnabledFromOptions();
    }

    function studioUnifiedCapabilitiesText(cap) {
      if (!cap || typeof cap !== "object") return "";
      const parts = [];
      if (cap.chat) parts.push("对话");
      if (cap.listModels) parts.push("列出模型");
      if (cap.local) parts.push("本机");
      parts.push("非流式 v1");
      return parts.length ? "能力：" + parts.join(" · ") : "";
    }

    function isStudioGatewayProvider(pid) {
      pid = normalizeStudioLlmProvider(pid);
      return pid === "hermes" || pid === "openclaw";
    }

    function studioVendorModelOptions(pid) {
      const pre = studioLlmPreset(pid);
      return (pre.models && pre.models.length ? pre.models : [pre.model]).filter(Boolean);
    }

    function resolveStudioModelForVendor(pid, raw) {
      pid = normalizeStudioLlmProvider(pid);
      const opts = studioVendorModelOptions(pid);
      let m = String(raw || "").trim();
      if (m === "__custom__") m = "";
      if (m && opts.includes(m)) return m;
      const slot = getStudioModelSlot(pid);
      if (slot && opts.includes(slot)) return slot;
      return studioLlmPreset(pid).model || opts[0] || "";
    }

    function getStudioModelSlot(pid) {
      pid = normalizeStudioLlmProvider(pid);
      const primaryModelEl = document.getElementById("usPrimaryModel");
      if (primaryModelEl) {
        const activeProv = getPrimaryStudioProvider();
        if (activeProv === pid) {
          const mv = String(primaryModelEl.value || "").trim();
          if (mv && mv !== "__custom__") return mv;
        }
      }
      const card = document.querySelector(`.studio-llm-card[data-prov="${pid}"]`);
      const modEl = card?.querySelector(".us-card-model");
      if (modEl) {
        let mv = String(modEl.value || "").trim();
        if (mv && mv !== "__custom__") return mv;
      }
      const models = getStudioLlmModels();
      if (models[pid]) return String(models[pid]).trim();
      const llm = state.data.userStudio?.llm || {};
      if (normalizeStudioLlmProvider(llm.provider) === pid && llm.model) return String(llm.model).trim();
      return "";
    }

    function readStudioPrimaryBaseUrl(vendor) {
      vendor = normalizeStudioLlmProvider(vendor);
      const pre = studioLlmPreset(vendor);
      const card = document.getElementById("studioPrimaryLlmCard");
      if (card) {
        const manualRow = card.querySelector(".us-primary-base-manual");
        const manualOn = manualRow && manualRow.style.display !== "none";
        if (manualOn) {
          const manual = String(document.getElementById("usPrimaryBaseUrl")?.value || "").trim();
          if (manual) return manual;
        }
      }
      return getStudioBaseUrlForProvider(vendor) || pre.baseUrl || "";
    }

    function buildStudioPrimaryLlmHtml(us) {
      const llm = us.llm || {};
      const curProv = normalizeStudioLlmProvider(llm.provider || "openai");
      const gatewayActive = isStudioGatewayProvider(curProv);
      const proto = studioPrimaryProtocolFromProvider(curProv);
      const vendor = studioPrimaryVendorFromState(us);
      const pre = studioLlmPreset(vendor);
      const slotKey = getStudioApiKeyForProvider(vendor) || String(llm.apiKey || "").trim();
      const model = resolveStudioModelForVendor(vendor, getStudioModelSlot(vendor));
      const manualFlag = isStudioManualBaseUrlFor(vendor);
      const baseUrl = getStudioBaseUrlForProvider(vendor) || String(llm.baseUrl || "").trim() || pre.baseUrl || "";
      const showCloudFields = proto === "openai" || proto === "ollama";
      const vendorOpts = LLM_UNIFIED_CLOUD_VENDORS.map((v) => {
        const sel = v === vendor ? " selected" : "";
        return `<option value="${esc(v)}"${sel}>${esc(studioLlmPreset(v).label)}</option>`;
      }).join("");
      const modelOpts = studioVendorModelOptions(vendor);
      const modelSelect = modelOpts.map((m) => `<option value="${esc(m)}"${m === model ? " selected" : ""}>${esc(m)}</option>`).join("");
      const u = us.llmUnified || {};
      const testStatus = u.testStatus || {};
      const statusCls = testStatus.ok ? "ok" : (testStatus.message ? "err" : "");
      const statusText = testStatus.message
        ? (testStatus.ok ? "最近测试：通过" : "最近测试：失败 — " + String(testStatus.message))
        : "填写密钥后点「测试连接」";
      const keyLabel = proto === "ollama" ? "API Key（可选）" : "API Key";
      const keyType = "text";
      const displayAutoUrl = !manualFlag && vendor !== "custom" && baseUrl
        ? ("自动使用官方接口：" + baseUrl)
        : (pre.baseUrl ? "自动使用官方接口：" + pre.baseUrl : "按厂商自动配置");
      const gatewayHint = gatewayActive
        ? `<div class="hint mini" style="margin-bottom:8px">当前活动对话为 <strong>${esc(curProv)}</strong>（本机 Gateway），请在下方「本机 Gateway」管理；此处配置 HTTP 对话模型。</div>`
        : "";
      return `
<div class="card studio-primary-llm-card" id="studioPrimaryLlmCard">
  <div class="title">对话模型</div>
  <div class="hint mini">Niuma Chat 与牛马对话均使用此配置；保存后自动同步到 Niuma Chat。Hermes / OpenClaw 请用下方 Gateway 区，勿与云端 API 混选。</div>
  ${gatewayHint}
  <div class="row">
    <div class="label">连接方式</div>
    <select id="usLlmProtocolId" data-nosave="1">
      <option value="openai"${proto === "openai" ? " selected" : ""}>云端（OpenAI 兼容）</option>
      <option value="ollama"${proto === "ollama" ? " selected" : ""}>Ollama（本地）</option>
    </select>
  </div>
  <div class="row" id="usLlmUnifiedVendorRow" style="${proto === "openai" ? "" : "display:none"}">
    <div class="label">厂商</div>
    <select id="usLlmUnifiedVendor" data-nosave="1">${vendorOpts}</select>
  </div>
  <div id="studioPrimaryCloudFields" style="${showCloudFields ? "" : "display:none"}">
    <div class="row"><div class="label">${keyLabel}</div><input id="usPrimaryApiKey" class="ctl studio-api-key-input" type="${keyType}" data-nosave="1" value="${esc(slotKey)}" placeholder="${esc(pre.keyPh || "API Key")}" autocomplete="off" spellcheck="false"></div>
    <div class="row us-primary-base-auto" style="display:${manualFlag || vendor === "custom" ? "none" : ""}">
      <div class="label">接口地址</div>
      <div class="studio-url-auto">${esc(displayAutoUrl)}</div>
      <a href="#" class="studio-url-manual-link" id="usPrimaryBaseManualLink"${vendor === "custom" ? ' style="display:none"' : ""}>使用中转 / 私有网关？</a>
    </div>
    <div class="row us-primary-base-manual" style="display:${manualFlag || vendor === "custom" ? "" : "none"}">
      <div class="label">Base URL</div>
      <input id="usPrimaryBaseUrl" class="ctl" type="text" data-nosave="1" value="${esc(manualFlag || vendor === "custom" ? baseUrl : "")}" placeholder="https://你的中转地址/v1">
    </div>
    <div class="row us-primary-minimax" id="usPrimaryMinimaxRegionRow" style="${vendor === "minimax" ? "" : "display:none"}">
      <div class="label">MiniMax 节点</div>
      <div class="inline" style="gap:8px;flex-wrap:wrap">
        <button type="button" class="btn us-primary-minimax-cn">国内 · minimaxi.com</button>
        <button type="button" class="btn us-primary-minimax-intl">国际 · minimax.io</button>
      </div>
    </div>
    <div class="row"><div class="label">模型</div>
      <select id="usPrimaryModel" class="ctl" data-nosave="1">${modelSelect}</select>
    </div>
    <div class="inline" style="margin-top:8px;flex-wrap:wrap;gap:8px">
      <button type="button" class="btn primary" id="btnStudioPrimaryLlmTest">测试连接</button>
    </div>
    <div class="hint mini studio-llm-card-status ${statusCls}" id="usLlmUnifiedTestHint">${esc(statusText)}</div>
  </div>
  <div id="studioPrimaryLocalHint" class="hint mini" style="${proto === "ollama" ? "" : "display:none"}">Ollama 本地模型：填写 Base URL / Model 后测试连接。</div>
</div>`;
    }

    function studioPrimaryProtocolFromProvider(pid) {
      pid = normalizeStudioLlmProvider(pid);
      if (pid === "ollama") return "ollama";
      if (isStudioGatewayProvider(pid)) return "openai";
      return "openai";
    }

    function studioPrimaryVendorFromState(us) {
      const pid = normalizeStudioLlmProvider(us?.llm?.provider || "openai");
      if (!isStudioGatewayProvider(pid)) {
        const proto = studioPrimaryProtocolFromProvider(pid);
        if (proto === "ollama") return "ollama";
        return LLM_UNIFIED_CLOUD_VENDORS.includes(pid) ? pid : "openai";
      }
      const unifiedVendor = normalizeStudioLlmProvider(us?.llmUnified?.active?.vendor || "");
      if (unifiedVendor && !isStudioGatewayProvider(unifiedVendor)) return unifiedVendor;
      const modelSlots = Object.keys(us?.options?.llmModels || {});
      const modelHit = modelSlots.find((k) => !isStudioGatewayProvider(k) && STUDIO_LLM_PRESETS[k]);
      if (modelHit) return normalizeStudioLlmProvider(modelHit);
      const keySlots = Object.keys(us?.options?.llmApiKeys || {}).filter((k) => !isStudioGatewayProvider(k));
      if (keySlots.length) return normalizeStudioLlmProvider(keySlots[0]);
      return "openai";
    }

    function getPrimaryStudioProvider() {
      const proto = String(document.getElementById("usLlmProtocolId")?.value || "openai").trim();
      if (proto === "ollama") return "ollama";
      return normalizeStudioLlmProvider(document.getElementById("usLlmUnifiedVendor")?.value || "openai");
    }

    function stashStudioPrimaryFromDom(opts) {
      opts = opts || {};
      const activatePrimary = !!opts.activatePrimary;
      const card = document.getElementById("studioPrimaryLlmCard");
      if (!card) return;
      const prov = getPrimaryStudioProvider();
      const pre = studioLlmPreset(prov);
      const key = normalizeStudioApiKey(document.getElementById("usPrimaryApiKey")?.value || "");
      const model = resolveStudioModelForVendor(prov, document.getElementById("usPrimaryModel")?.value || "");
      const manualRow = card.querySelector(".us-primary-base-manual");
      const manualOn = manualRow && manualRow.style.display !== "none";
      let baseUrl = pre.baseUrl || "";
      if (manualOn) {
        baseUrl = String(document.getElementById("usPrimaryBaseUrl")?.value || "").trim();
        stashStudioBaseUrlForProvider(prov, baseUrl, true);
      } else {
        stashStudioBaseUrlForProvider(prov, getStudioBaseUrlForProvider(prov) || pre.baseUrl || "", false);
        baseUrl = getStudioBaseUrlForProvider(prov) || pre.baseUrl || "";
      }
      if (key) stashStudioApiKeyForProvider(prov, key);
      stashStudioModelForProvider(prov, model);
      const curActive = normalizeStudioLlmProvider(state?.data?.userStudio?.llm?.provider || "");
      const keepGatewayActive = isStudioGatewayProvider(curActive) && !activatePrimary;
      if (!keepGatewayActive) {
        setStudioLlmCardProviders([prov]);
        mergeUserStudioState({
          llm: { provider: prov, apiKey: key, baseUrl, model },
          options: { llmCardProviders: [prov], llmManagerEnabled: true }
        });
      } else {
        mergeUserStudioState({
          options: { llmManagerEnabled: true }
        });
      }
      if (!state.data.userStudio.llmUnified) state.data.userStudio.llmUnified = {};
      state.data.userStudio.llmUnified.active = {
        protocolId: studioPrimaryProtocolFromProvider(prov),
        vendor: prov,
        model,
        baseUrl
      };
    }

    function applyStudioPrimaryFromDom() {
      applyStudioUnifiedProtocolFromDom({ activatePrimary: true });
    }

    function applyStudioUnifiedProtocolFromDom(opts) {
      opts = opts || {};
      const protoEl = document.getElementById("usLlmProtocolId");
      if (!protoEl) return;
      const proto = String(protoEl.value || "openai").trim();
      let vendor = "openai";
      if (proto === "ollama") vendor = "ollama";
      else vendor = normalizeStudioLlmProvider(document.getElementById("usLlmUnifiedVendor")?.value || "openai");
      const pre = studioLlmPreset(vendor);
      const baseUrl = getStudioBaseUrlForProvider(vendor) || pre.baseUrl || "";
      const model = resolveStudioModelForVendor(vendor, getStudioModelForProvider(vendor));
      const apiKey = getStudioApiKeyForProvider(vendor);
      if (!!opts.activatePrimary) {
        setStudioLlmCardProviders([vendor]);
        mergeUserStudioState({
          llm: { provider: vendor, baseUrl, model, apiKey },
          options: { llmCardProviders: [vendor], llmManagerEnabled: true }
        });
      }
      stashStudioPrimaryFromDom({ activatePrimary: !!opts.activatePrimary });
      if (!state.data.userStudio.llmUnified) state.data.userStudio.llmUnified = {};
      state.data.userStudio.llmUnified.active = {
        protocolId: proto,
        vendor,
        model,
        baseUrl
      };
    }

    function studioLlmProviderOptions(selected) {
      return Object.keys(STUDIO_LLM_PRESETS)
        .map((k) => {
          const p = STUDIO_LLM_PRESETS[k];
          return { value: k, label: p.label };
        })
        .map((it) => `<option value="${esc(it.value)}"${it.value === selected ? " selected" : ""}>${esc(it.label)}</option>`)
        .join("");
    }

    function fillStudioLlmModelSelect(pid, currentModel, targetEl) {
      const sel = targetEl || document.getElementById("usLlmModel");
      if (!sel) return;
      const pre = studioLlmPreset(pid);
      const models = (pre.models && pre.models.length ? pre.models : [pre.model]).filter(Boolean);
      const cur = String(currentModel || "").trim();
      const opts = models.slice();
      if (cur && opts.indexOf(cur) < 0) opts.unshift(cur);
      if (pid === "custom") {
        if (sel.tagName === "SELECT") {
          const inp = document.createElement("input");
          inp.className = sel.className || "ctl us-card-model";
          inp.type = "text";
          inp.setAttribute("data-nosave", "1");
          inp.dataset.prov = pid;
          inp.value = cur;
          inp.placeholder = "模型名称";
          inp.autocomplete = "off";
          if (sel.id) inp.id = sel.id;
          sel.replaceWith(inp);
        } else {
          sel.value = cur;
        }
        return;
      }
      let sel2 = sel;
      if (sel.tagName !== "SELECT") {
        const wrap = sel.parentElement;
        const nu = document.createElement("select");
        nu.className = sel.className || "ctl us-card-model";
        nu.setAttribute("data-nosave", "1");
        nu.dataset.prov = pid;
        if (sel.id) nu.id = sel.id;
        if (wrap) wrap.replaceChild(nu, sel);
        sel2 = nu;
      }
      sel2.innerHTML =
        opts.map((m) => `<option value="${esc(m)}">${esc(m)}</option>`).join("") +
        `<option value="__custom__">其他（手动输入）…</option>`;
      if (cur && opts.indexOf(cur) >= 0) sel2.value = cur;
      else if (cur) {
        const o = document.createElement("option");
        o.value = cur;
        o.textContent = cur + "（当前）";
        o.selected = true;
        sel2.insertBefore(o, sel2.lastElementChild);
      } else sel2.value = opts[0] || "";
    }

    const STUDIO_MINIMAX_BASE_CN = "https://api.minimaxi.com/anthropic";
    const STUDIO_MINIMAX_BASE_INTL = "https://api.minimax.io/anthropic";
    const STUDIO_LOCAL_AGENT_ICONS = {
      openclaw: "https://app.local/assets/icons/ai/openclaw.svg",
      hermes: "https://app.local/assets/icons/ai/hermes.png"
    };

    function normalizeStudioApiKey(raw) {
      let k = String(raw || "").trim();
      k = k.replace(/^\s*Bearer\s+/i, "").replace(/^['"]|['"]$/g, "").replace(/\s+/g, "");
      return k;
    }

    function inferStudioProviderFromApiKey(key) {
      key = normalizeStudioApiKey(key);
      if (/^sk-cp-/i.test(key)) return "minimax";
      if (/^sk-[a-f0-9]{20,}$/i.test(key) && key.length <= 40) return "deepseek";
      if (/^sk-ant-/i.test(key)) return "claude";
      if (/^AIza/i.test(key)) return "gemini";
      return "";
    }

    function applyStudioPrimaryVendorUi(prov) {
      prov = normalizeStudioLlmProvider(prov);
      const vendEl = document.getElementById("usLlmUnifiedVendor");
      if (vendEl && vendEl.value !== prov) vendEl.value = prov;
      if (prov === "minimax") {
        syncStudioMinimaxRegionUi(getStudioBaseUrlForProvider("minimax") || STUDIO_MINIMAX_BASE_CN);
      }
      const pre = studioLlmPreset(prov);
      const modEl = document.getElementById("usPrimaryModel");
      if (modEl && modEl.tagName === "SELECT") {
        fillStudioLlmModelSelect(prov, getStudioModelForProvider(prov) || pre.model, modEl);
      }
      const auto = document.querySelector("#studioPrimaryLlmCard .studio-url-auto");
      if (auto) {
        const bu = getStudioBaseUrlForProvider(prov) || pre.baseUrl || "";
        if (bu) auto.textContent = "自动使用官方接口：" + bu;
      }
    }

    function swapStudioPrimaryVendorKeyUi(prevVendor, newVendor) {
      const el = document.getElementById("usPrimaryApiKey");
      if (!el) return;
      const cur = normalizeStudioApiKey(el.value || "");
      if (cur) stashStudioApiKeyForProvider(prevVendor, cur);
      el.value = getStudioApiKeyForProvider(newVendor) || "";
    }

    function summarizeStudioLlmTestError(rawErr, prov, endpoint, diagnostics, extra) {
      const diag = String(diagnostics || extra?.diagnostics || "").trim();
      const phase = String(extra?.phase || "").trim();
      const httpSt = Number(extra?.status || 0);
      let err = String(rawErr || extra?.message || "").trim() || "API 测试失败";
      const p = normalizeStudioLlmProvider(prov || "");
      const ep = String(endpoint || "").trim();
      if (/鉴权失败|余额不足|insufficient balance|402|401|404|429/i.test(err) && err.length > 24) {
        if (ep && !err.includes(ep)) err += "\n接口: " + ep;
        return err;
      }
      if (diag) {
        if (!err.includes(diag.split("\n")[0]))
          err = err + "\n" + diag;
        else if (diag.length > err.length)
          err = diag;
        return err;
      }
      if (/HTTP\s*429\b/i.test(err)) {
        err = "HTTP 429（限流/额度不足）。若用官方：检查 API Billing/额度；若用中转：检查中转限流/共享池。";
      } else if (/HTTP\s*401\b/i.test(err) || httpSt === 401) {
        err = (p ? p.charAt(0).toUpperCase() + p.slice(1) + " " : "") + "鉴权失败 (401)：请核对 API Key 是否有效、有余额，且 Base URL 与密钥区域一致。";
      } else if (/HTTP\s*402\b/i.test(err) || httpSt === 402 || /insufficient balance/i.test(err)) {
        err = (p === "deepseek" ? "DeepSeek" : (p ? p.charAt(0).toUpperCase() + p.slice(1) : "服务商"))
          + " 账户余额不足 (402)：密钥格式正确但需充值后才能调用。请到官方控制台充值后重试。";
      } else if (/HTTP\s*403\b/i.test(err) || httpSt === 403) {
        err = "HTTP 403：密钥可能无该模型权限，或账号被限制。";
      } else if (/HTTP\s*404\b/i.test(err) || httpSt === 404) {
        err = "HTTP 404：Base URL 或路径错误，请确认 …/v1/chat/completions 完整。";
      }
      if (phase === "dns")
        err = "DNS 解析失败 · " + err;
      else if (phase === "proxy")
        err = "代理问题 · " + err;
      else if (phase === "tls")
        err = "TLS/证书问题 · " + err;
      else if (phase === "connect")
        err = "TCP 连接失败 · " + err;
      else if (phase === "timeout")
        err = "请求超时 · " + err;
      if (ep && !err.includes(ep))
        err += "\n接口: " + ep;
      return err;
    }

    function buildStudioLlmTimeoutHint(prov, baseUrl, diagnostics) {
      const diag = String(diagnostics || "").trim();
      if (diag) return diag;
      const p = normalizeStudioLlmProvider(prov || "");
      const base = String(baseUrl || "").trim();
      const target = p === "minimax"
        ? (base || "https://api.minimax.io/anthropic")
        : p === "deepseek"
          ? (base || "https://api.deepseek.com/v1")
          : p === "openai"
            ? (base || "https://api.openai.com/v1")
            : (base || "目标 API");
      const label = p ? p.charAt(0).toUpperCase() + p.slice(1) : "当前服务商";
      return label + " 测试超时（25s）：宿主未在时限内返回结果。请重载牛马.ahk 后重开设置中心，并查看 Cache\\debug\\studio_llm_test.log；若日志为空多为桥接未达 AHK，而非 API 网络问题。目标: " + target;
    }

    /** 各服务商分槽保存的 API Key（与 Niuma Chat 的 state.apiKeys 一致） */
    function getStudioLlmApiKeys() {
      const o = state.data.userStudio?.options || {};
      const m = o.llmApiKeys;
      if (!m || typeof m !== "object" || Array.isArray(m)) return {};
      const out = {};
      Object.keys(m).forEach((k) => {
        const nk = normalizeStudioLlmProvider(k);
        const v = normalizeStudioApiKey(m[k]);
        if (v) out[nk] = v;
      });
      return out;
    }

    function getStudioApiKeyForProvider(pid) {
      pid = normalizeStudioLlmProvider(pid);
      const keys = getStudioLlmApiKeys();
      if (keys[pid]) return keys[pid];
      const llm = state.data.userStudio?.llm || {};
      const llmProv = normalizeStudioLlmProvider(llm.provider);
      if (llmProv === pid && llm.apiKey)
        return normalizeStudioApiKey(llm.apiKey);
      return "";
    }

    function readStudioApiKeyFromEl(el, prov) {
      if (!el) return "";
      const candidates = [
        el.value,
        el.getAttribute && el.getAttribute("value"),
        el.defaultValue
      ];
      for (const c of candidates) {
        const k = normalizeStudioApiKey(c || "");
        if (k.length >= 8) return k;
      }
      return normalizeStudioApiKey(getStudioApiKeyForProvider(prov) || "");
    }

    function readStudioPrimaryApiKey(prov) {
      prov = normalizeStudioLlmProvider(prov || getPrimaryStudioProvider());
      const el = document.querySelector("#studioPrimaryLlmCard #usPrimaryApiKey")
        || document.getElementById("usPrimaryApiKey");
      const key = readStudioApiKeyFromEl(el, prov);
      if (key) stashStudioApiKeyForProvider(prov, key);
      return key;
    }

    function readStudioCardApiKey(pid) {
      pid = normalizeStudioLlmProvider(pid);
      const card = document.querySelector(`.studio-llm-card[data-prov="${pid}"]`);
      const el = card?.querySelector(".us-card-key") || document.getElementById("usLlmApiKey");
      const key = readStudioApiKeyFromEl(el, pid);
      if (key) stashStudioApiKeyForProvider(pid, key);
      return key;
    }

    function stashStudioApiKeyForProvider(pid, key) {
      pid = normalizeStudioLlmProvider(pid);
      key = normalizeStudioApiKey(key);
      if (!state.data.userStudio) state.data.userStudio = { options: {} };
      if (!state.data.userStudio.options) state.data.userStudio.options = {};
      const keys = getStudioLlmApiKeys();
      if (key) keys[pid] = key;
      else delete keys[pid];
      state.data.userStudio.options.llmApiKeys = keys;
    }

    function stashStudioApiKeyFromDom() {
      if (document.getElementById("studioLlmCards")) return stashAllStudioCardsFromDom();
      const provEl = document.getElementById("usLlmProvider");
      const keyEl = document.getElementById("usLlmApiKey");
      if (!provEl || !keyEl) return false;
      stashStudioApiKeyForProvider(provEl.value, keyEl.value);
      return true;
    }

    function getStudioLlmModels() {
      const o = state.data.userStudio?.options || {};
      const m = o.llmModels;
      if (!m || typeof m !== "object" || Array.isArray(m)) return {};
      const out = {};
      Object.keys(m).forEach((k) => {
        const nk = normalizeStudioLlmProvider(k);
        const v = String(m[k] || "").trim();
        if (v) out[nk] = v;
      });
      return out;
    }

    function getStudioModelForProvider(pid) {
      pid = normalizeStudioLlmProvider(pid);
      return resolveStudioModelForVendor(pid, getStudioModelSlot(pid));
    }

    function stashStudioModelForProvider(pid, model) {
      pid = normalizeStudioLlmProvider(pid);
      model = String(model || "").trim();
      if (!state.data.userStudio) state.data.userStudio = { options: {} };
      if (!state.data.userStudio.options) state.data.userStudio.options = {};
      const models = getStudioLlmModels();
      if (model) models[pid] = model;
      else delete models[pid];
      state.data.userStudio.options.llmModels = models;
    }

    const STUDIO_LLM_LS_KEY = "niuma_studio_llm_cards_v1";

    function saveStudioLlmCardsToLocalStorage(pl) {
      try {
        const src = pl || buildStudioLlmPersistPayload();
        localStorage.setItem(STUDIO_LLM_LS_KEY, JSON.stringify({
          explicit: true,
          cards: src?.options?.llmCardProviders || [],
          keys: src?.options?.llmApiKeys || {},
          models: src?.options?.llmModels || {},
          llm: src?.llm || {},
          ts: Date.now()
        }));
      } catch (_) {}
    }

    function loadStudioLlmCardsFromLocalStorage() {
      if (Array.isArray(state.data.userStudio?.options?.llmCardProviders)) return;
      try {
        const raw = localStorage.getItem(STUDIO_LLM_LS_KEY);
        if (!raw) return;
        const data = JSON.parse(raw);
        if (!data?.explicit) return;
        mergeUserStudioState({
          llm: data.llm || {},
          options: {
            llmCardProviders: Array.isArray(data.cards) ? data.cards : [],
            llmApiKeys: data.keys || {},
            llmModels: data.models || {}
          }
        });
        state._studioCardsExplicit = true;
      } catch (_) {}
    }

    function getStudioLlmCardProviders() {
      const opt = state.data.userStudio?.options || {};
      if (state._studioCardsExplicit || Array.isArray(opt.llmCardProviders)) {
        return (opt.llmCardProviders || [])
          .map((p) => normalizeStudioLlmProvider(p))
          .filter((p, i, arr) => STUDIO_LLM_PRESETS[p] && arr.indexOf(p) === i);
      }
      const keys = Object.keys(getStudioLlmApiKeys());
      const prov = normalizeStudioLlmProvider(state.data.userStudio?.llm?.provider || "openai");
      const ordered = [];
      const seen = new Set();
      [prov, ...keys].forEach((p) => {
        p = normalizeStudioLlmProvider(p);
        if (!seen.has(p) && STUDIO_LLM_PRESETS[p]) {
          seen.add(p);
          ordered.push(p);
        }
      });
      return ordered.length ? ordered : ["openai"];
    }

    function markStudioCardsExplicit() {
      state._studioCardsExplicit = true;
    }

    function setStudioLlmCardProviders(list) {
      if (!state.data.userStudio) state.data.userStudio = { options: {} };
      if (!state.data.userStudio.options) state.data.userStudio.options = {};
      const out = [];
      const seen = new Set();
      (list || []).forEach((p) => {
        p = normalizeStudioLlmProvider(p);
        if (!STUDIO_LLM_PRESETS[p] || seen.has(p)) return;
        seen.add(p);
        out.push(p);
      });
      state.data.userStudio.options.llmCardProviders = out;
      markStudioCardsExplicit();
    }

    function getActiveStudioLlmProvider() {
      const radio = document.querySelector('input[name="usLlmActiveProvider"]:checked');
      if (radio) return normalizeStudioLlmProvider(radio.value);
      return normalizeStudioLlmProvider(state.data.userStudio?.llm?.provider || "openai");
    }

    function maskStudioApiKey(key) {
      const k = normalizeStudioApiKey(key);
      if (!k) return "";
      if (k.length <= 8) return "••••";
      return k.slice(0, 4) + "…" + k.slice(-4);
    }

    function stashAllStudioCardsFromDom() {
      const cards = document.querySelectorAll(".studio-llm-card[data-prov]");
      if (!cards.length) return false;
      const providers = [];
      cards.forEach((card) => {
        const pid = normalizeStudioLlmProvider(card.dataset.prov || "");
        if (!pid) return;
        providers.push(pid);
        const keyEl = card.querySelector(".us-card-key");
        if (keyEl) stashStudioApiKeyForProvider(pid, keyEl.value);
        const manualFlag = card.dataset.manualBase === "1" || isStudioManualBaseUrlFor(pid);
        const manualInp = card.querySelector(".us-card-base-manual-input");
        const hiddenBase = card.querySelector(".us-card-base-hidden");
        const url =
          manualFlag && manualInp
            ? manualInp.value
            : hiddenBase?.value || getStudioBaseUrlForProvider(pid);
        stashStudioBaseUrlForProvider(pid, url, manualFlag);
        const modEl = card.querySelector(".us-card-model");
        if (modEl) {
          let mv = String(modEl.value || "").trim();
          if (mv === "__custom__") mv = "";
          if (modEl.tagName !== "SELECT") mv = String(modEl.value || "").trim();
          stashStudioModelForProvider(pid, resolveStudioModel(pid, mv));
        }
      });
      if (providers.length) setStudioLlmCardProviders(providers);
      return true;
    }

    const STUDIO_PROVIDER_HOST_HINTS = {
      kimi: ["moonshot.cn", "moonshot.ai"],
      deepseek: ["deepseek.com"],
      openai: ["api.openai.com"],
      minimax: ["minimax"],
      gemini: ["generativelanguage.googleapis.com"],
      claude: ["anthropic.com"],
      qwen: ["dashscope.aliyuncs.com"],
      glm: ["bigmodel.cn"],
      zhipu: ["bigmodel.cn"],
      siliconflow: ["siliconflow.cn"],
      ollama: ["11434", "ollama"]
    };

    function studioBaseUrlMatchesProvider(pid, url) {
      pid = normalizeStudioLlmProvider(pid);
      const u = String(url || "").trim().toLowerCase();
      if (!u || pid === "custom" || pid === "openclaw" || pid === "hermes") return true;
      const hints = STUDIO_PROVIDER_HOST_HINTS[pid];
      if (!hints || !hints.length) return true;
      return hints.some((h) => u.includes(h));
    }

    function getStudioLlmBaseUrls() {
      const o = state.data.userStudio?.options || {};
      const m = o.llmBaseUrls;
      if (!m || typeof m !== "object" || Array.isArray(m)) return {};
      const out = {};
      Object.keys(m).forEach((k) => {
        const nk = normalizeStudioLlmProvider(k);
        const v = String(m[k] || "").trim();
        if (v && studioBaseUrlMatchesProvider(nk, v)) out[nk] = v;
      });
      return out;
    }

    function getStudioLlmManualFlags() {
      const o = state.data.userStudio?.options || {};
      const m = o.llmManualBaseUrl;
      if (!m || typeof m !== "object" || Array.isArray(m)) return {};
      const out = {};
      Object.keys(m).forEach((k) => {
        out[normalizeStudioLlmProvider(k)] = !!m[k];
      });
      return out;
    }

    function isStudioManualBaseUrlFor(pid) {
      pid = normalizeStudioLlmProvider(pid);
      if (pid === "custom") return true;
      const flags = getStudioLlmManualFlags();
      if (flags[pid]) return true;
      return false;
    }

    function getStudioBaseUrlForProvider(pid) {
      pid = normalizeStudioLlmProvider(pid);
      const map = getStudioLlmBaseUrls();
      if (map[pid]) return map[pid];
      const llm = state.data.userStudio?.llm || {};
      if (normalizeStudioLlmProvider(llm.provider) === pid) {
        const u = String(llm.baseUrl || "").trim();
        if (u && studioBaseUrlMatchesProvider(pid, u)) return u;
      }
      return studioLlmPreset(pid).baseUrl || "";
    }

    function stashStudioBaseUrlForProvider(pid, url, manual) {
      pid = normalizeStudioLlmProvider(pid);
      url = String(url || "").trim();
      if (!state.data.userStudio) state.data.userStudio = { options: {} };
      if (!state.data.userStudio.options) state.data.userStudio.options = {};
      const urls = getStudioLlmBaseUrls();
      const flags = getStudioLlmManualFlags();
      if (url && studioBaseUrlMatchesProvider(pid, url)) urls[pid] = url;
      else delete urls[pid];
      if (manual) flags[pid] = true;
      else delete flags[pid];
      state.data.userStudio.options.llmBaseUrls = urls;
      state.data.userStudio.options.llmManualBaseUrl = flags;
    }

    function stashStudioBaseUrlFromDom() {
      if (document.getElementById("studioLlmCards")) return stashAllStudioCardsFromDom();
      const provEl = document.getElementById("usLlmProvider");
      if (!provEl) return false;
      const pid = normalizeStudioLlmProvider(provEl.value);
      const manualInp = document.getElementById("usLlmBaseUrlManual");
      const baseEl = document.getElementById("usLlmBaseUrl");
      const url =
        state._studioManualBaseUrl && manualInp
          ? manualInp.value
          : baseEl?.value || getStudioBaseUrlForProvider(pid);
      stashStudioBaseUrlForProvider(pid, url, !!state._studioManualBaseUrl);
      return true;
    }

    function syncStudioMinimaxRegionUi(url) {
      const isIntl = /minimax\.io/i.test(String(url || ""));
      const cnSel = ".us-primary-minimax-cn, .us-minimax-cn";
      const intlSel = ".us-primary-minimax-intl, .us-minimax-intl";
      document.querySelectorAll(cnSel).forEach((btn) => btn.classList.toggle("primary", !isIntl));
      document.querySelectorAll(intlSel).forEach((btn) => btn.classList.toggle("primary", isIntl));
    }

    function setStudioMinimaxRegion(url, pid) {
      pid = normalizeStudioLlmProvider(pid || getPrimaryStudioProvider() || getActiveStudioLlmProvider());
      stashStudioBaseUrlForProvider(pid, url, false);
      const primaryAuto = document.querySelector("#studioPrimaryLlmCard .studio-url-auto");
      if (primaryAuto) primaryAuto.textContent = "自动使用官方接口：" + url;
      syncStudioMinimaxRegionUi(url);
      const card = document.querySelector(`.studio-llm-card[data-prov="${pid}"]`);
      if (card) {
        card.dataset.manualBase = "0";
        const hidden = card.querySelector(".us-card-base-hidden");
        const manualInp = card.querySelector(".us-card-base-manual-input");
        const autoRow = card.querySelector(".us-card-base-auto");
        const manualRow = card.querySelector(".us-card-base-manual");
        if (hidden) hidden.value = url;
        if (manualInp) manualInp.value = "";
        if (autoRow) autoRow.style.display = "";
        if (manualRow) manualRow.style.display = "none";
      } else {
        const baseEl = document.getElementById("usLlmBaseUrl");
        const manual = document.getElementById("usLlmBaseUrlManual");
        state._studioManualBaseUrl = false;
        if (baseEl) baseEl.value = url;
        if (manual) manual.value = "";
        updateStudioBaseUrlUi("minimax");
      }
      setStatus("已切换 MiniMax 节点：" + url, "ok");
      persistStudioLlmToDisk({ silent: true, immediate: true });
    }

    function normalizeMoonshotBaseUrl(url) {
      let u = String(url || "").trim().replace(/\/+$/, "");
      if (/^https?:\/\/api\.moonshot\.(cn|ai)$/i.test(u)) u += "/v1";
      return u;
    }

    function resolveStudioBaseUrl(pid, raw, manualFlag) {
      pid = normalizeStudioLlmProvider(pid);
      const manual = pid === "custom" || !!manualFlag || isStudioManualBaseUrlFor(pid);
      let r = normalizeMoonshotBaseUrl(raw);
      if (manual) {
        if (r && studioBaseUrlMatchesProvider(pid, r)) return r;
        if (pid !== "custom" && r && !studioBaseUrlMatchesProvider(pid, r))
          return getStudioBaseUrlForProvider(pid);
        return r || getStudioBaseUrlForProvider(pid);
      }
      return getStudioBaseUrlForProvider(pid);
    }

    function resolveStudioModel(pid, raw) {
      let m = String(raw || "").trim();
      if (m === "__custom__") m = "";
      pid = normalizeStudioLlmProvider(pid);
      if (m) return m;
      return studioLlmPreset(pid).model || "";
    }

    function updateStudioBaseUrlUi(pid) {
      const autoRow = document.getElementById("usLlmBaseUrlAutoRow");
      const manualRow = document.getElementById("usLlmBaseUrlManualRow");
      const autoEl = document.getElementById("usLlmBaseUrlAuto");
      const baseEl = document.getElementById("usLlmBaseUrl");
      const link = document.getElementById("usLlmBaseUrlManualLink");
      const pre = studioLlmPreset(pid);
      const isCustom = pid === "custom";
      const showManual = isCustom || !!state._studioManualBaseUrl;
      if (autoRow) autoRow.style.display = showManual ? "none" : "";
      if (manualRow) manualRow.style.display = showManual ? "" : "none";
      if (!showManual && baseEl) baseEl.value = pre.baseUrl || "";
      const manualInp = document.getElementById("usLlmBaseUrlManual");
      if (showManual && manualInp && !manualInp.value.trim()) manualInp.value = pre.baseUrl || "";
      if (autoEl && !showManual) {
        autoEl.textContent = "自动使用官方接口：" + (pre.baseUrl || "（按服务商）") + "，无需填写。";
      }
      if (link) link.style.display = isCustom ? "none" : "";
    }

    function applyStudioLlmPresetUi(onlyIfEmpty) {
      const provEl = document.getElementById("usLlmProvider");
      if (!provEl) return;
      const pid = normalizeStudioLlmProvider(provEl.value);
      const pre = studioLlmPreset(pid);
      const keyEl = document.getElementById("usLlmApiKey");
      const baseEl = document.getElementById("usLlmBaseUrl");
      const hintEl = document.getElementById("usLlmProviderHint");
      const mod0 = document.getElementById("usLlmModel");
      const curModel =
        mod0?.tagName === "SELECT" ? mod0.value || "" : String(mod0?.value || "").trim();
      fillStudioLlmModelSelect(pid, onlyIfEmpty ? curModel || pre.model : pre.model || curModel);
      const modEl = document.getElementById("usLlmModel");
      if (keyEl) {
        keyEl.placeholder = pre.keyPh || "API Key";
        keyEl.value = getStudioApiKeyForProvider(pid);
      }
      const bu = getStudioBaseUrlForProvider(pid);
      if (baseEl && pid !== "custom" && !state._studioManualBaseUrl) baseEl.value = bu || pre.baseUrl || "";
      else if (baseEl && (!onlyIfEmpty || !baseEl.value.trim())) baseEl.value = bu || pre.baseUrl || "";
      const manualInp = document.getElementById("usLlmBaseUrlManual");
      if (manualInp && state._studioManualBaseUrl) {
        const mu = getStudioBaseUrlForProvider(pid);
        if (!onlyIfEmpty || !manualInp.value.trim() || !studioBaseUrlMatchesProvider(pid, manualInp.value))
          manualInp.value = mu || pre.baseUrl || "";
      }
      if (modEl && modEl.tagName === "SELECT" && (!onlyIfEmpty || !modEl.value)) {
        if (pre.model && modEl.querySelector(`option[value="${pre.model}"]`)) modEl.value = pre.model;
      } else if (modEl && modEl.tagName !== "SELECT" && (!onlyIfEmpty || !modEl.value.trim())) {
        modEl.value = pre.model || "";
      }
      if (hintEl) {
        hintEl.textContent =
          (pre.hint || "") +
          (pid === "custom" ? "" : " Base URL 已自动配置，一般无需手填。");
      }
      const mmRow = document.getElementById("usMinimaxRegionRow");
      if (mmRow) mmRow.style.display = pid === "minimax" ? "" : "none";
      updateStudioBaseUrlUi(pid);
    }

    function renderStudioLlmCardHtml(pid, activeProv) {
      pid = normalizeStudioLlmProvider(pid);
      const pre = studioLlmPreset(pid);
      const slotKey = getStudioApiKeyForProvider(pid);
      const hasKey = !!slotKey || pid === "ollama";
      const isDefault = normalizeStudioLlmProvider(activeProv) === pid;
      const manualFlag = isStudioManualBaseUrlFor(pid);
      const baseUrl = getStudioBaseUrlForProvider(pid);
      const model = getStudioModelForProvider(pid);
      const statusCls = hasKey ? "ok" : "";
      const statusText = hasKey
        ? (pid === "ollama" ? "本地模型" : `已配置 ${maskStudioApiKey(slotKey)}`)
        : "未填写 Key";
      const showManual = pid === "custom" || manualFlag;
      const autoText = pre.baseUrl
        ? `自动使用官方接口：${pre.baseUrl}`
        : "按服务商自动配置，一般无需手填";
      return `<div class="studio-llm-card${isDefault ? " is-default" : ""}" data-prov="${esc(pid)}" data-manual-base="${showManual ? "1" : "0"}">
  <div class="studio-llm-card-head">
    <div class="studio-llm-card-title-row">
      <strong>${esc(pre.label)}</strong>
      <span class="studio-llm-card-status ${statusCls}">${esc(statusText)}</span>
    </div>
    <div class="studio-llm-card-actions">
      <label class="studio-llm-default"><input type="radio" name="usLlmActiveProvider" value="${esc(pid)}" data-nosave="1"${isDefault ? " checked" : ""}> 默认使用</label>
      <button type="button" class="btn studio-llm-remove" data-prov="${esc(pid)}">移除</button>
    </div>
  </div>
  <div class="row"><div class="label">${pid === "openclaw" ? "Gateway Token" : pid === "hermes" ? "API Server Key" : "API Key"}</div><input class="us-card-key" data-prov="${esc(pid)}" type="${pid === "openclaw" || pid === "hermes" ? "text" : "password"}" data-nosave="1" value="${esc(slotKey)}" placeholder="${esc(pre.keyPh || "API Key")}" autocomplete="off"></div>
  ${pid === "openclaw" ? `<div class="hint mini">本机网关 <code>http://127.0.0.1:18789</code> · WebSocket 对话，与云端 API Key 无关</div>` : ""}
  ${pid === "hermes" ? `<div class="hint mini">本机 API <code>http://127.0.0.1:8642/v1</code> · 读取 <code>~/.hermes/.env</code> 中 API_SERVER_KEY</div>` : ""}
  <div class="row us-card-base-auto" data-prov="${esc(pid)}" style="display:${showManual ? "none" : ""}">
    <div class="label">接口地址</div>
    <div class="studio-url-auto">${esc(autoText)}</div>
    <input class="us-card-base-hidden" type="hidden" data-nosave="1" value="${esc(baseUrl)}">
    <a href="#" class="studio-url-manual-link us-card-manual-link" data-prov="${esc(pid)}"${pid === "custom" ? ' style="display:none"' : ""}>使用中转 / 私有网关？手动指定</a>
  </div>
  <div class="row us-card-base-manual" data-prov="${esc(pid)}" style="display:${showManual ? "" : "none"}">
    <div class="label">Base URL${pid === "custom" ? "" : "（手动）"}</div>
    <input class="us-card-base-manual-input ctl" type="text" data-nosave="1" value="${esc(showManual ? baseUrl : "")}" placeholder="https://你的中转地址/v1">
  </div>
  <div class="row"><div class="label">模型</div><select id="usLlmModel_${esc(pid)}" class="ctl us-card-model" data-prov="${esc(pid)}" data-nosave="1"></select></div>
  <div class="row us-card-minimax" data-prov="${esc(pid)}" style="display:${pid === "minimax" ? "" : "none"}">
    <div class="label">MiniMax 节点</div>
    <div class="inline" style="flex-wrap:wrap;gap:8px">
      <button type="button" class="btn us-minimax-cn" data-prov="${esc(pid)}">国内 · minimaxi.com</button>
      <button type="button" class="btn us-minimax-intl" data-prov="${esc(pid)}">国际 · minimax.io</button>
    </div>
  </div>
  <div class="hint mini us-card-hint">${esc(pre.hint || "")}</div>
  <div class="inline" style="margin-top:8px;flex-wrap:wrap;gap:8px">
    ${pid === "openclaw" ? `<button type="button" class="btn primary studio-openclaw-import-card" data-prov="${esc(pid)}">一键连接</button>` : ""}
    ${pid === "hermes" ? `<button type="button" class="btn primary studio-hermes-import-card" data-prov="${esc(pid)}">一键连接</button>` : ""}
    <button type="button" class="btn studio-llm-test-card" data-prov="${esc(pid)}">${pid === "openclaw" ? "检测 Gateway" : pid === "hermes" ? "检测 API Server" : "测试"}</button>
  </div>
</div>`;
    }

    function buildStudioLlmCardsHtml(activeProv) {
      const providers = getStudioLlmCardProviders();
      const cardsHtml = providers.length
        ? providers.map((pid) => renderStudioLlmCardHtml(pid, activeProv)).join("")
        : `<div class="studio-llm-empty">尚未配置：可点上方<strong>一键连接本机 Hermes / OpenClaw</strong>，或<strong>添加云模型 API</strong> 填写密钥。</div>`;
      return `${buildStudioLocalConnectGridHtml(providers)}
<div class="studio-llm-add-bar">
  <button type="button" class="btn" id="btnAddStudioLlmCard">添加云模型 API</button>
</div>
<div id="studioLlmCards" class="studio-llm-cards">${cardsHtml}</div>`;
    }

    function studioOpenClawConfigured() {
      return !!getStudioOpenClawEffectiveToken();
    }

    function buildStudioOpenClawQuickStatus(cardProviders) {
      const hasCard = (cardProviders || getStudioLlmCardProviders()).includes("openclaw");
      const st = state.studioOpenClawStatus || {};
      let statusCls = "";
      let statusText = "检测中…";
      if (studioOpenClawConfigured()) {
        if (st.gatewayOk === true) {
          statusCls = "ok";
          statusText = hasCard ? "已连接" : "点下方按钮保存";
        } else if (st.gatewayOk === false) {
          statusText = "Token 已就绪 · 网关未启";
        } else {
          statusCls = "ok";
          statusText = hasCard ? "Token 已保存" : "先测试再保存";
        }
      } else {
        statusText = "先测试连接";
      }
      return { statusCls, statusText };
    }

    function studioHermesConnVerified() {
      const st = state.studioHermesStatus || {};
      const draft = state.studioHermesQuickDraft;
      return !!(st.testPassed || st.gatewayOk === true || (draft && draft.testOk === true));
    }

    function studioHermesMarkConnVerified(ok) {
      state.studioHermesStatus = state.studioHermesStatus || {};
      if (ok) {
        state.studioHermesStatus.testPassed = true;
        state.studioHermesStatus.gatewayOk = true;
        if (!state.studioHermesStatus.apiServerState)
          state.studioHermesStatus.apiServerState = "connected";
        const draft = state.studioHermesQuickDraft;
        if (draft) draft.testOk = true;
      } else {
        state.studioHermesStatus.testPassed = false;
      }
      updateStudioHermesQuickStatusDom();
      updateStudioHermesQuickActionButtons();
      updateStudioHermesRestartBtn();
    }

    function buildStudioHermesQuickStatus(cardProviders) {
      const hasCard = (cardProviders || getStudioLlmCardProviders()).includes("hermes");
      const st = state.studioHermesStatus || {};
      let statusCls = "";
      let statusText = "检测中…";
      if (studioHermesConnVerified()) {
        statusCls = "ok";
        statusText = hasCard ? "已连接" : "测试通过 · 可确认保存";
      } else if (studioHermesConfigured()) {
        if (st.gatewayOk === true) {
          statusCls = "ok";
          statusText = hasCard ? "已连接" : "点下方按钮保存";
        } else if (st.gatewayOk === false) {
          statusText =
            st.apiServerState === "connected"
              ? "8642 已启 · Key 需对齐"
              : "Key 已保存 · 8642 未启";
        } else {
          statusCls = "ok";
          statusText = hasCard ? "Key 已保存" : "先测试再保存";
        }
      } else if (st.probeError) {
        statusText = "先测试连接";
      } else {
        statusText = "先测试连接";
      }
      return { statusCls, statusText };
    }

    function buildStudioLocalConnectGridHtml(cardProviders) {
      const oc = buildStudioOpenClawQuickStatus(cardProviders);
      const hm = buildStudioHermesQuickStatus(cardProviders);
      const ocIcon = esc(STUDIO_LOCAL_AGENT_ICONS.openclaw);
      const hmIcon = esc(STUDIO_LOCAL_AGENT_ICONS.hermes);
      return `<div class="studio-local-connect-grid">
  <div class="studio-local-quick studio-local-quick--hermes" id="studioHermesQuick">
    <div class="studio-local-quick-head">
      <div class="studio-local-quick-title">
        <img class="studio-local-quick-icon is-raster" src="${hmIcon}" alt="" width="36" height="36" decoding="async">
        <div>
          <strong>Hermes Agent</strong>
          <div class="hint mini" style="margin-top:4px">本机 API <code>8642/v1</code> · <code>~/.hermes/.env</code></div>
        </div>
      </div>
      <span class="studio-hermes-quick-status studio-local-quick-status ${hm.statusCls}" id="studioHermesQuickStatus">${esc(hm.statusText)}</span>
    </div>
    <div class="studio-local-quick-actions">
      <button type="button" class="btn" id="btnStudioHermesQuickTest">测试连接</button>
      <button type="button" class="btn primary" id="btnStudioHermesQuickConfirm" disabled>确认保存</button>
    </div>
    <button type="button" class="btn2" id="btnStudioHermesQuickRestart" style="width:100%;margin-top:8px;display:none">重启 Hermes Gateway</button>
    <div class="hint mini" style="margin-top:8px">测试会优先用 <code>.env</code> 的 Key 访问 <code>127.0.0.1:8642</code>，通过后再确认保存</div>
  </div>
  <div class="studio-local-quick studio-local-quick--openclaw" id="studioOpenClawQuick">
    <div class="studio-local-quick-head">
      <div class="studio-local-quick-title">
        <img class="studio-local-quick-icon" src="${ocIcon}" alt="" width="36" height="36" decoding="async">
        <div>
          <strong>OpenClaw Gateway</strong>
          <div class="hint mini" style="margin-top:4px">本机 WebSocket · <code>127.0.0.1:18789</code></div>
        </div>
      </div>
      <span class="studio-openclaw-quick-status studio-local-quick-status ${oc.statusCls}" id="studioOpenClawQuickStatus">${esc(oc.statusText)}</span>
    </div>
    <div class="studio-local-quick-actions">
      <button type="button" class="btn" id="btnStudioOpenClawQuickTest">测试连接</button>
      <button type="button" class="btn primary" id="btnStudioOpenClawQuickConfirm" disabled>确认保存</button>
    </div>
    <div class="hint mini" style="margin-top:8px">先<strong>测试连接</strong>（读 Token + 检测 18789），通过后再<strong>确认保存</strong></div>
  </div>
</div>`;
    }

    function studioHermesConfigured() {
      return !!getStudioHermesEffectiveToken();
    }

    function studioOpenClawPersistFromDraft(draft) {
      const pid = "openclaw";
      const pre = studioLlmPreset(pid);
      const token = normalizeStudioApiKey(draft.token || "");
      const baseUrl = String(draft.baseUrl || "").trim();
      if (!token || !baseUrl) return false;
      stashStudioApiKeyForProvider(pid, token);
      stashStudioBaseUrlForProvider(pid, baseUrl, false);
      stashStudioModelForProvider(pid, draft.model || pre.model || "gateway");
      const list = [pid];
      setStudioLlmCardProviders(list);
      mergeUserStudioState({
        llm: { provider: pid, apiKey: token, baseUrl: baseUrl, model: draft.model || pre.model },
        options: {
          llmCardProviders: list,
          llmApiKeys: { ...getStudioLlmApiKeys(), openclaw: token },
          llmBaseUrls: { ...getStudioLlmBaseUrls(), openclaw: baseUrl },
          llmModels: { ...getStudioLlmModels(), openclaw: draft.model || pre.model },
          llmManagerEnabled: true
        }
      });
      render();
      persistStudioCardsNow(false);
      state.studioOpenClawQuickDraft = null;
      updateStudioOpenClawQuickActionButtons();
      return true;
    }

    async function studioOpenClawQuickLoadDraft() {
      post({ type: "invokeAction", op: "syncNiumaChatLlmToStudio" });
      await new Promise((r) => setTimeout(r, 350));
      const stat = await requestStudioOpenClawStatusRefresh(true);
      const token = normalizeStudioApiKey(stat.token || stat.niumaToken || getStudioApiKeyForProvider("openclaw") || "");
      if (!token) {
        throw new Error("未读到 Gateway Token。请启动本机 OpenClaw 或在 NiumaChat 中连接后重试。");
      }
      const pre = studioLlmPreset("openclaw");
      const baseUrl = "http://" + (stat.host || "127.0.0.1") + ":" + (Number(stat.port) || 18789);
      const draft = {
        token,
        source: String(stat.source || "").trim(),
        host: stat.host || "127.0.0.1",
        port: Number(stat.port) || 18789,
        baseUrl,
        model: pre.model || "gateway",
        gatewayOk: stat.gatewayOk === true,
        testOk: false,
        testError: ""
      };
      state.studioOpenClawQuickDraft = draft;
      stashStudioApiKeyForProvider("openclaw", token);
      stashStudioBaseUrlForProvider("openclaw", baseUrl, false);
      stashStudioModelForProvider("openclaw", draft.model);
      state.studioOpenClawStatus = state.studioOpenClawStatus || {};
      state.studioOpenClawStatus.token = token;
      state.studioOpenClawStatus.source = draft.source;
      state.studioOpenClawStatus.gatewayOk = draft.gatewayOk;
      updateStudioOpenClawQuickStatusDom();
      updateStudioOpenClawQuickActionButtons();
      return draft;
    }

    async function studioOpenClawQuickTest() {
      if (studioOpenClawImportRunning) return;
      const btn = document.getElementById("btnStudioOpenClawQuickTest");
      const confirmBtn = document.getElementById("btnStudioOpenClawQuickConfirm");
      studioOpenClawImportRunning = true;
      if (btn) btn.disabled = true;
      if (confirmBtn) confirmBtn.disabled = true;
      try {
        setStatus("正在读取 OpenClaw 配置并测试 Gateway…", "ok");
        const draft = await studioOpenClawQuickLoadDraft();
        const pl = buildStudioLlmPayloadForProvider("openclaw");
        pl.llm.apiKey = draft.token;
        pl.llm.baseUrl = draft.baseUrl;
        pl.llm.model = draft.model || pl.llm.model;
        const r = await studioTestLlmPromise(pl);
        state._studioTestInFlight = false;
        draft.testOk = !!r.ok;
        draft.testError = String(r.error || "").trim();
        state.studioOpenClawStatus.gatewayOk = draft.testOk;
        updateStudioOpenClawQuickStatusDom();
        updateStudioOpenClawQuickActionButtons();
        if (draft.testOk) {
          setStatus("OpenClaw 测试通过，可点「确认保存」。", "ok");
        } else {
          setStatus(draft.testError || "OpenClaw Gateway 未响应，请启动 openclaw gateway。", "err");
        }
      } catch (e) {
        state.studioOpenClawQuickDraft = null;
        updateStudioOpenClawQuickActionButtons();
        setStatus(e?.message || String(e || "测试失败"), "err");
      } finally {
        studioOpenClawImportRunning = false;
        if (btn) btn.disabled = false;
      }
    }

    function studioOpenClawQuickConfirm() {
      const draft = state.studioOpenClawQuickDraft;
      if (!draft || draft.testOk !== true) {
        setStatus("请先点「测试连接」，通过后再「确认保存」。", "err");
        return;
      }
      if (!studioOpenClawPersistFromDraft(draft)) {
        setStatus("保存失败：配置不完整", "err");
        return;
      }
      setStatus("OpenClaw 已确认保存到智能定制。", "ok");
    }

    function studioConnectOpenClawFromSettings() {
      studioOpenClawQuickTest();
    }

    function updateStudioHermesQuickActionButtons() {
      const confirmBtn = document.getElementById("btnStudioHermesQuickConfirm");
      if (!confirmBtn) return;
      const draft = state.studioHermesQuickDraft;
      confirmBtn.disabled = !(draft && draft.testOk === true);
    }

    function updateStudioOpenClawQuickActionButtons() {
      const confirmBtn = document.getElementById("btnStudioOpenClawQuickConfirm");
      if (!confirmBtn) return;
      const draft = state.studioOpenClawQuickDraft;
      confirmBtn.disabled = !(draft && draft.testOk === true);
    }

    function studioHermesPersistFromDraft(draft) {
      const pid = "hermes";
      const pre = studioLlmPreset(pid);
      const token = normalizeStudioApiKey(draft.token || "");
      const baseUrl = String(draft.baseUrl || "").trim();
      if (!token || !baseUrl) return false;
      stashStudioApiKeyForProvider(pid, token);
      stashStudioBaseUrlForProvider(pid, baseUrl, false);
      stashStudioModelForProvider(pid, draft.model || pre.model || "hermes-agent");
      const list = [pid];
      setStudioLlmCardProviders(list);
      mergeUserStudioState({
        llm: { provider: pid, apiKey: token, baseUrl: baseUrl, model: draft.model || pre.model },
        options: {
          llmCardProviders: list,
          llmApiKeys: { ...getStudioLlmApiKeys(), hermes: token },
          llmBaseUrls: { ...getStudioLlmBaseUrls(), hermes: baseUrl },
          llmManagerEnabled: true
        }
      });
      render();
      persistStudioCardsNow(false);
      state.studioHermesQuickDraft = null;
      updateStudioHermesQuickActionButtons();
      return true;
    }

    function studioHermesNormalizeHost(host) {
      const h = String(host || "").trim();
      return h === "localhost" || h === "" ? "127.0.0.1" : h;
    }

    function updateStudioHermesRestartBtn() {
      const btn = document.getElementById("btnStudioHermesQuickRestart");
      if (!btn) return;
      const st = state.studioHermesStatus || {};
      const show = !!st.canRestartGateway && st.gatewayOk !== true;
      btn.style.display = show ? "" : "none";
    }

    function requestStudioHermesGatewayRestart() {
      return new Promise((resolve, reject) => {
        const timer = setTimeout(() => {
          studioHermesRestartPending = null;
          reject(new Error("Hermes Gateway 重启超时"));
        }, 60000);
        studioHermesRestartPending = {
          resolve: (d) => {
            clearTimeout(timer);
            studioHermesRestartPending = null;
            resolve(d || {});
          },
          reject: (e) => {
            clearTimeout(timer);
            studioHermesRestartPending = null;
            reject(e);
          }
        };
        post({ type: "hermes_restart_gateway" });
      });
    }

    async function studioHermesQuickRestartGateway() {
      const btn = document.getElementById("btnStudioHermesQuickRestart");
      if (btn) btn.disabled = true;
      setStatus("正在重启 Hermes Gateway…", "ok");
      try {
        const rr = await requestStudioHermesGatewayRestart();
        if (!rr.ok) throw new Error(rr.error || "重启失败");
        setStatus("Gateway 已重启，正在重新测试…", "ok");
        await new Promise((r) => setTimeout(r, 900));
        await studioHermesQuickTest();
      } catch (e) {
        setStatus(e?.message || String(e || "重启失败"), "err");
      } finally {
        if (btn) btn.disabled = false;
        updateStudioHermesRestartBtn();
      }
    }

    async function studioHermesQuickLoadDraft() {
      post({ type: "invokeAction", op: "syncNiumaChatLlmToStudio" });
      await new Promise((r) => setTimeout(r, 350));
      let stat = await requestStudioHermesStatusRefresh(true);
      let token = normalizeStudioApiKey(stat.token || "");
      if (!token) {
        await new Promise((r) => setTimeout(r, 400));
        stat = await requestStudioHermesStatusRefresh(true);
        token = normalizeStudioApiKey(stat.token || "");
      }
      if (!token) {
        token = normalizeStudioApiKey(getStudioApiKeyForProvider("hermes") || "");
      }
      if (!token) {
        throw new Error(
          "未读到 Hermes Key。请先安装 Hermes 并点「测试连接」（会自动写入 .env）；写入后请完全退出并重启 Hermes 再试。"
        );
      }
      const pre = studioLlmPreset("hermes");
      const host = studioHermesNormalizeHost(stat.host);
      const port = Number(stat.port) || 8642;
      const baseUrl = "http://" + host + ":" + port + "/v1";
      const source = String(stat.source || "").trim();
      const draft = {
        token,
        source,
        host,
        port,
        baseUrl,
        model: pre.model || "hermes-agent",
        gatewayOk: stat.gatewayOk === true,
        apiServerState: String(stat.apiServerState || "").trim(),
        canRestartGateway: !!stat.canRestartGateway,
        testOk: false,
        testError: ""
      };
      state.studioHermesQuickDraft = draft;
      state.studioHermesStatus.canRestartGateway = draft.canRestartGateway;
      stashStudioApiKeyForProvider("hermes", token);
      stashStudioBaseUrlForProvider("hermes", baseUrl, false);
      stashStudioModelForProvider("hermes", draft.model);
      state.studioHermesStatus = state.studioHermesStatus || {};
      state.studioHermesStatus.token = token;
      state.studioHermesStatus.source = source;
      state.studioHermesStatus.host = draft.host;
      state.studioHermesStatus.port = draft.port;
      state.studioHermesStatus.gatewayOk = draft.gatewayOk;
      updateStudioHermesQuickStatusDom();
      updateStudioHermesQuickActionButtons();
      updateStudioHermesRestartBtn();
      return draft;
    }

    async function studioHermesQuickTest() {
      if (studioHermesImportRunning) return;
      const btn = document.getElementById("btnStudioHermesQuickTest");
      const confirmBtn = document.getElementById("btnStudioHermesQuickConfirm");
      studioHermesImportRunning = true;
      if (btn) btn.disabled = true;
      if (confirmBtn) confirmBtn.disabled = true;
      try {
        setStatus("正在读取 Hermes 配置并测试 API Server（127.0.0.1:8642）…", "ok");
        let draft = await studioHermesQuickLoadDraft();
        let statAfter = await requestStudioHermesStatusRefresh(true);
        if (statAfter.gatewayOk === true) {
          draft.gatewayOk = true;
          draft.token = normalizeStudioApiKey(statAfter.token || draft.token);
        }
        const srcHint = draft.source ? draft.source.replace(/^.*[\\/]/, "") : ".env";
        if (draft.gatewayOk) {
          studioHermesMarkConnVerified(true);
          setStatus("Hermes 测试通过（" + srcHint + " · 8642 正常），可点「确认保存」。", "ok");
          return;
        }
        const pl = buildStudioLlmPayloadForProvider("hermes");
        pl.llm.apiKey = draft.token;
        pl.llm.baseUrl = draft.baseUrl;
        pl.llm.model = draft.model || pl.llm.model;
        state._studioLastTestProv = "hermes";
        const r = await studioTestLlmPromise(pl);
        state._studioTestInFlight = false;
        state._studioLastTestProv = "";
        draft.testOk = !!r.ok;
        draft.testError = String(r.error || "").trim();
        if (draft.testOk) studioHermesMarkConnVerified(true);
        else studioHermesMarkConnVerified(false);
        if (draft.testOk) {
          setStatus("Hermes 测试通过（" + srcHint + "），可点「确认保存」。", "ok");
        } else {
          setStatus(draft.testError || "Hermes 测试未通过。", "err");
        }
      } catch (e) {
        state.studioHermesQuickDraft = null;
        updateStudioHermesQuickActionButtons();
        setStatus(e?.message || String(e || "测试失败"), "err");
      } finally {
        studioHermesImportRunning = false;
        if (btn) btn.disabled = false;
      }
    }

    function studioHermesQuickConfirm() {
      const draft = state.studioHermesQuickDraft;
      if (!draft || draft.testOk !== true) {
        setStatus("请先点「测试连接」，通过后再「确认保存」。", "err");
        return;
      }
      if (!studioHermesPersistFromDraft(draft)) {
        setStatus("保存失败：配置不完整", "err");
        return;
      }
      studioHermesMarkConnVerified(true);
      setStatus("Hermes 已确认保存到智能定制，并与 NiumaChat 配置对齐。", "ok");
    }

    function studioConnectHermesFromSettings() {
      studioHermesQuickTest();
    }

    let studioModalMinimaxUrl = STUDIO_MINIMAX_BASE_CN;
    let studioModalBound = false;

    let studioOpenClawImportPending = null;
    const studioOpenClawPendingByReqId = new Map();
    let studioOpenClawImportRunning = false;
    let studioOpenClawStatusRefreshGen = 0;
    let studioHermesImportPending = null;
    let studioHermesRestartPending = null;
    let studioHermesImportRunning = false;
    let studioHermesStatusRefreshGen = 0;

    function getStudioOpenClawEffectiveToken() {
      const saved = getStudioApiKeyForProvider("openclaw");
      if (saved) return saved;
      const st = state.studioOpenClawStatus || {};
      return normalizeStudioApiKey(st.token || st.niumaToken || "");
    }

    function updateStudioOpenClawQuickStatusDom() {
      const el = document.getElementById("studioOpenClawQuickStatus");
      if (!el) return;
      const key = getStudioOpenClawEffectiveToken();
      const st = state.studioOpenClawStatus || {};
      const hasCard = getStudioLlmCardProviders().includes("openclaw");
      let cls = "";
      let text = "先测试连接";
      if (key) {
        if (st.gatewayOk === true) {
          cls = "ok";
          text = hasCard ? "已连接" : "可确认保存";
        } else if (st.gatewayOk === false) {
          cls = "ok";
          text = hasCard ? "Token 已保存 · 网关未启" : "先测试再保存";
        } else {
          cls = "ok";
          text = hasCard ? "Token 已保存" : "先测试再保存";
        }
      } else if (st.probeError) {
        text = "先测试连接";
      }
      el.className = "studio-openclaw-quick-status studio-local-quick-status" + (cls ? " " + cls : "");
      el.textContent = text;
    }

    function finishStudioOpenClawPending(reqId, payload, err) {
      const rid = String(reqId || "");
      const entry = rid ? studioOpenClawPendingByReqId.get(rid) : studioOpenClawImportPending;
      if (!entry) return false;
      clearTimeout(entry.timer);
      if (rid) studioOpenClawPendingByReqId.delete(rid);
      if (studioOpenClawImportPending === entry) studioOpenClawImportPending = null;
      if (err) entry.reject(err);
      else entry.resolve(payload || {});
      return true;
    }

    const STUDIO_OPENCLAW_STATUS_TIMEOUT_MS = 20000;

    function requestStudioOpenClawStatusRefresh(force) {
      return new Promise((resolve, reject) => {
        const reqId = "oc_stat_" + Date.now();
        const timer = setTimeout(() => {
          if (!finishStudioOpenClawPending(reqId, null, new Error("OpenClaw 状态检测超时（20s）。Gateway 若在运行请重载牛马后再试；否则执行 openclaw gateway restart"))) return;
        }, STUDIO_OPENCLAW_STATUS_TIMEOUT_MS);
        const entry = {
          reqId,
          resolve,
          reject,
          timer
        };
        studioOpenClawImportPending = entry;
        studioOpenClawPendingByReqId.set(reqId, entry);
        post({ type: "refreshOpenClawStudioStatus", force: !!force, reqId });
      });
    }

    function applyStudioOpenClawStatusPayload(msg) {
      const token = normalizeStudioApiKey(msg.token || msg.niumaToken || "");
      state.studioOpenClawStatus = {
        token: String(msg.token || "").trim(),
        niumaToken: String(msg.niumaToken || "").trim(),
        source: String(msg.source || "").trim(),
        host: String(msg.host || "127.0.0.1").trim(),
        port: Number(msg.port) || 18789,
        gatewayOk: msg.gatewayOk === true ? true : msg.gatewayOk === false ? false : null,
        gatewayError: String(msg.gatewayError || "").trim(),
        probeError: ""
      };
      if (!token) {
        const dbg = String(msg.debug || msg.gatewayError || "").trim();
        state.studioOpenClawStatus.probeError = dbg
          ? "未读到 Gateway Token（" + dbg + "）"
          : "未读到 Gateway Token（已尝试 openclaw.json 片段读取、device-auth、CLI；请重载牛马后重试）";
      } else if (msg.gatewayOk === false) {
        const gwErr = String(msg.gatewayError || "").trim();
        state.studioOpenClawStatus.probeError = gwErr
          ? ("Gateway 未就绪：" + gwErr)
          : "Gateway 未就绪：请在本机终端执行 openclaw gateway restart";
      } else {
        state.studioOpenClawStatus.probeError = "";
      }
      updateStudioOpenClawQuickStatusDom();
      return token;
    }

    async function refreshStudioOpenClawStatusAsync() {
      const gen = ++studioOpenClawStatusRefreshGen;
      try {
        const active = normalizeStudioLlmProvider(getActiveStudioLlmProvider());
        if (active !== "openclaw" && !getStudioLlmCardProviders().includes("openclaw")) {
          return;
        }
        const stat = await requestStudioOpenClawStatusRefresh(false);
        if (gen !== studioOpenClawStatusRefreshGen) return;
        applyStudioOpenClawStatusPayload(stat);
      } catch (e) {
        if (gen !== studioOpenClawStatusRefreshGen) return;
        state.studioOpenClawStatus = state.studioOpenClawStatus || {};
        state.studioOpenClawStatus.probeError = e?.message || "检测失败";
        updateStudioOpenClawQuickStatusDom();
        if (state.activeTab === "customize" && normalizeStudioLlmProvider(getActiveStudioLlmProvider()) === "openclaw") {
          setStatus(state.studioOpenClawStatus.probeError, "err");
        }
      }
    }

    function getStudioHermesEffectiveToken() {
      const saved = getStudioApiKeyForProvider("hermes");
      if (saved) return saved;
      const st = state.studioHermesStatus || {};
      return normalizeStudioApiKey(st.token || st.niumaToken || "");
    }

    function updateStudioHermesQuickStatusDom() {
      const el = document.getElementById("studioHermesQuickStatus");
      if (!el) return;
      const key = getStudioHermesEffectiveToken();
      const st = state.studioHermesStatus || {};
      const hasCard = getStudioLlmCardProviders().includes("hermes");
      let cls = "";
      let text = "先测试连接";
      const envHint = st.installLabel ? st.installLabel : "";
      if (studioHermesConnVerified()) {
        cls = "ok";
        text = hasCard ? "已连接" : "测试通过 · 可确认保存";
      } else if (key) {
        if (st.gatewayOk === true) {
          cls = "ok";
          text = (hasCard ? "已连接 · API Server 正常" : "API Server 已连通 · 可确认保存") + (envHint ? " · " + envHint : "");
        } else if (st.gatewayOk === false) {
          cls = "ok";
          const portHint =
            st.apiServerState === "connected"
              ? "8642 已启 · Key 需对齐"
              : "Key 已保存 · 8642 未启";
          text =
            (hasCard ? portHint : "先测试再保存") +
            (st.apiServerState && st.apiServerState !== "connected" ? " · " + st.apiServerState : "") +
            (envHint ? " · " + envHint : "");
        } else {
          cls = "ok";
          text = hasCard ? "Key 已保存" : "先测试再保存";
        }
      } else if (st.probeError) {
        text = st.installKind === "none" ? "未安装 Hermes" : "先测试连接";
      } else if (st.installKind === "none") {
        text = "先测试连接";
      }
      el.className = "studio-hermes-quick-status studio-local-quick-status" + (cls ? " " + cls : "");
      el.textContent = text;
    }

    function requestStudioHermesStatusRefresh(force) {
      return new Promise((resolve, reject) => {
        const reqId = "hm_stat_" + Date.now();
        const timer = setTimeout(() => {
          if (studioHermesImportPending && studioHermesImportPending.reqId === reqId) {
            studioHermesImportPending = null;
            reject(new Error("Hermes 状态检测超时"));
          }
        }, 20000);
        studioHermesImportPending = {
          reqId,
          resolve: (d) => {
            clearTimeout(timer);
            studioHermesImportPending = null;
            resolve(d || {});
          },
          reject: (e) => {
            clearTimeout(timer);
            studioHermesImportPending = null;
            reject(e);
          }
        };
        post({ type: "refreshHermesStudioStatus", force: !!force, ensureEnv: true, reqId });
      });
    }

    function updateStudioPrimaryLlmTestHint(text, cls = "") {
      const el = document.getElementById("usLlmUnifiedTestHint");
      if (!el) return;
      el.textContent = String(text || "");
      el.className = "hint mini studio-llm-card-status" + (cls ? " " + cls : "");
    }

    function applyStudioHermesStatusPayload(msg) {
      const token = normalizeStudioApiKey(msg.token || "");
      const prevPassed = !!(state.studioHermesStatus && state.studioHermesStatus.testPassed);
      let gw =
        msg.gatewayOk === true ? true : msg.gatewayOk === false ? false : null;
      const apiSt = String(msg.apiServerState || "").trim();
      if (gw !== true && apiSt === "connected" && token)
        gw = true;
      if (prevPassed)
        gw = true;
      state.studioHermesStatus = {
        token: String(msg.token || "").trim(),
        source: String(msg.source || "").trim(),
        host: String(msg.host || "127.0.0.1").trim(),
        port: Number(msg.port) || 8642,
        apiEnabled: !!msg.apiEnabled,
        gatewayOk: gw,
        gatewayError: String(msg.gatewayError || "").trim(),
        installKind: String(msg.installKind || "none"),
        installLabel: String(msg.installLabel || "").trim(),
        apiServerState: apiSt,
        canRestartGateway: !!msg.canRestartGateway,
        testPassed: prevPassed || gw === true,
        probeError: ""
      };
      updateStudioHermesRestartBtn();
      if (!token) {
        const savedKey = getStudioApiKeyForProvider("hermes");
        if (savedKey) {
          state.studioHermesStatus.token = savedKey;
          state.studioHermesStatus.source = "niuma_chat";
          state.studioHermesStatus.probeError = "";
          updateStudioHermesQuickStatusDom();
          return savedKey;
        }
        const dbg = String(msg.debug || msg.gatewayError || "").trim();
        state.studioHermesStatus.probeError = dbg
          ? "未读到 API_SERVER_KEY（" + dbg + "）"
          : "未读到 API_SERVER_KEY。Windows 桌面版通常在 %LOCALAPPDATA%\\hermes\\.env；点「一键连接」可自动写入。";
      }
      updateStudioHermesQuickStatusDom();
      return token;
    }

    async function refreshStudioHermesStatusAsync() {
      const gen = ++studioHermesStatusRefreshGen;
      try {
        post({ type: "invokeAction", op: "syncNiumaChatLlmToStudio" });
        await new Promise((r) => setTimeout(r, 350));
        const stat = await requestStudioHermesStatusRefresh(false);
        if (gen !== studioHermesStatusRefreshGen) return;
        applyStudioHermesStatusPayload(stat);
      } catch (e) {
        if (gen !== studioHermesStatusRefreshGen) return;
        state.studioHermesStatus = state.studioHermesStatus || {};
        state.studioHermesStatus.probeError = e?.message || "检测失败";
        updateStudioHermesQuickStatusDom();
      }
    }

    async function runStudioHermesImportConnect(opts) {
      opts = opts || {};
      if (studioHermesImportRunning) return;
      const btn = opts.fromCard
        ? document.querySelector('.studio-hermes-import-card[data-prov="hermes"]')
        : document.getElementById("studioModalHermesImport");
      studioHermesImportRunning = true;
      if (btn) btn.disabled = true;
      const pid = "hermes";
      try {
        if (!opts.fromCard && !opts.fromSettingsGrid) {
          const provEl = document.getElementById("studioModalProvider");
          if (provEl && normalizeStudioLlmProvider(provEl.value) !== pid) provEl.value = pid;
          updateStudioModalMinimaxRow(pid);
        } else {
          stashAllStudioCardsFromDom();
        }
        setStatus("正在同步 NiumaChat 配置并检测 Hermes…", "ok");
        post({ type: "invokeAction", op: "syncNiumaChatLlmToStudio" });
        await new Promise((r) => setTimeout(r, 350));
        let stat = await requestStudioHermesStatusRefresh(true);
        let token = normalizeStudioApiKey(stat.token || getStudioApiKeyForProvider("hermes") || "");
        if (!token) {
          await new Promise((r) => setTimeout(r, 400));
          stat = await requestStudioHermesStatusRefresh(true);
          token = normalizeStudioApiKey(stat.token || getStudioApiKeyForProvider("hermes") || "");
        }
        const source = String(stat.source || "").trim();
        if (!token) {
          throw new Error(
            "未读到 Hermes Key。NiumaChat 若已能对话，请先在那边保存 Hermes 连接后再点「一键连接」；或启动 Hermes 桌面版并检查 %LOCALAPPDATA%\\hermes\\.env。"
          );
        }
        const pre = studioLlmPreset(pid);
        const baseUrl =
          "http://" + (stat.host || "127.0.0.1") + ":" + (Number(stat.port) || 8642) + "/v1";
        stashStudioApiKeyForProvider(pid, token);
        stashStudioBaseUrlForProvider(pid, baseUrl, false);
        stashStudioModelForProvider(pid, pre.model || "hermes-agent");
        if (!opts.fromCard) {
          const keyEl = document.getElementById("studioModalApiKey");
          if (keyEl) {
            keyEl.value = token;
            keyEl.type = "text";
          }
        } else {
          const card = document.querySelector('.studio-llm-card[data-prov="hermes"]');
          const keyInp = card?.querySelector(".us-card-key");
          if (keyInp) {
            keyInp.value = token;
            keyInp.type = "text";
          }
        }
        const srcHint = source ? source.replace(/^.*[\\/]/, "") : "~/.hermes/.env";
        state.studioHermesStatus = state.studioHermesStatus || {};
        state.studioHermesStatus.token = token;
        state.studioHermesStatus.source = source;
        state.studioHermesStatus.host = stat.host || "127.0.0.1";
        state.studioHermesStatus.port = Number(stat.port) || 8642;
        const gwOk = stat.gatewayOk === true;
        state.studioHermesStatus.gatewayOk = gwOk;
        state.studioHermesStatus.gatewayError = gwOk ? "" : String(stat.gatewayError || "");
        updateStudioHermesQuickStatusDom();
        setStatus(
          gwOk
            ? "已导入 API_SERVER_KEY（" + srcHint + "），API Server 正常。"
            : "已导入并保存 Key（" + srcHint + "）；请完全退出并重启 Hermes 桌面应用以启动 8642 API Server。",
          "ok"
        );
        const finishSave = function (gatewayOk) {
          if (opts.fromCard || opts.fromSettingsGrid) {
            const list = [...getStudioLlmCardProviders()];
            if (!list.includes(pid)) list.push(pid);
            setStudioLlmCardProviders(list);
            mergeUserStudioState({
              llm: {
                provider: pid,
                apiKey: token,
                baseUrl: baseUrl,
                model: pre.model
              },
              options: {
                llmCardProviders: list,
                llmApiKeys: { ...getStudioLlmApiKeys(), hermes: token },
                llmBaseUrls: { ...getStudioLlmBaseUrls(), hermes: baseUrl }
              }
            });
            render();
            persistStudioCardsNow(false);
            if (gatewayOk) setStatus("Hermes 一键连接成功，API Server 正常。", "ok");
            else
              setStatus(
                "Key 已保存。请完全退出并重启 Hermes 桌面应用以启动 API Server（" +
                  (stat.host || "127.0.0.1") +
                  ":" +
                  (Number(stat.port) || 8642) +
                  "）。",
                "ok"
              );
          } else {
            const defEl = document.getElementById("studioModalSetDefault");
            if (defEl && getStudioLlmCardProviders().length === 0) defEl.checked = true;
            confirmStudioLlmAddModal();
            setStatus(
              gatewayOk
                ? "Hermes 已导入、检测通过并已保存。"
                : "Key 已保存。请完全退出并重启 Hermes 桌面应用后再检测 API Server。",
              "ok"
            );
          }
        };
        finishSave(gwOk);
      } catch (e) {
        setStatus(e?.message || String(e || "连接失败"), "err");
      } finally {
        studioHermesImportRunning = false;
        if (btn) btn.disabled = false;
      }
    }

    function updateStudioModalMinimaxRow(pid) {
      const row = document.getElementById("studioModalMinimaxRow");
      const ocRow = document.getElementById("studioModalOpenClawRow");
      const ocOr = document.getElementById("studioModalOpenClawOrManual");
      const hmRow = document.getElementById("studioModalHermesRow");
      const hmOr = document.getElementById("studioModalHermesOrManual");
      const modelRow = document.getElementById("studioModalModelRow");
      const keyLabel = document.getElementById("studioModalApiKeyLabel");
      const hint = document.getElementById("studioModalHint");
      pid = normalizeStudioLlmProvider(pid);
      const pre = studioLlmPreset(pid);
      const isOc = pid === "openclaw";
      const isHm = pid === "hermes";
      if (row) row.style.display = pid === "minimax" ? "" : "none";
      if (ocRow) ocRow.style.display = isOc ? "" : "none";
      if (ocOr) ocOr.style.display = isOc ? "" : "none";
      if (hmRow) hmRow.style.display = isHm ? "" : "none";
      if (hmOr) hmOr.style.display = isHm ? "" : "none";
      if (modelRow) modelRow.style.display = isOc ? "none" : "";
      if (hint) {
        hint.textContent = isOc
          ? "已安装 OpenClaw 时优先点上方橙色按钮；Gateway 需在本机运行（默认端口 18789）。"
          : isHm
            ? "已安装 Hermes 时优先点上方按钮；需在 ~/.hermes/.env 配置 API Server 并 hermes gateway（默认 8642）。"
            : pre.hint || "";
      }
      const keyEl = document.getElementById("studioModalApiKey");
      if (keyEl) {
        keyEl.placeholder = pre.keyPh || "API Key";
        keyEl.type = isOc || isHm ? "text" : "password";
      }
      if (keyLabel) {
        keyLabel.textContent = isOc
          ? "Gateway Token（可选，一键连接会自动填入）"
          : isHm
            ? "API Server Key（可选，一键连接会自动填入）"
            : "API Key";
      }
      if (pid === "minimax") studioModalMinimaxUrl = STUDIO_MINIMAX_BASE_CN;
    }

    function requestStudioOpenClawHostProbe(force) {
      return new Promise((resolve, reject) => {
        const reqId = "oc_probe_" + Date.now();
        const timer = setTimeout(() => {
          if (!finishStudioOpenClawPending(reqId, null, new Error("读取本机 OpenClaw 配置超时"))) return;
        }, 12000);
        const entry = { reqId, resolve, reject, timer };
        studioOpenClawImportPending = entry;
        studioOpenClawPendingByReqId.set(reqId, entry);
        post({ type: "openclaw_probe_token", force: !!force, reqId });
      });
    }

    function studioTestLlmPromise(pl, opts) {
      opts = opts || {};
      const flat = opts.flat || {};
      const waitMs = 25000;
      const testId = "t_" + Date.now();
      return new Promise((resolve) => {
        const prov = normalizeStudioLlmProvider(pl?.llm?.provider || "");
        const baseUrl = String(pl?.llm?.baseUrl || "").trim();
        const timer = setTimeout(() => {
          if (!state._studioTestWaiter) return;
          state._studioTestWaiter = null;
          state._studioTestInFlight = false;
          state._studioLastTestProv = "";
          state._studioTestAckId = "";
          const timeoutErr = buildStudioLlmTimeoutHint(prov, baseUrl, "");
          pinStatus(timeoutErr, "err");
          updateStudioPrimaryLlmTestHint(timeoutErr.split("\n")[0], "err");
          resolve({ ok: false, error: timeoutErr });
        }, waitMs);
        state._studioTestAckId = testId;
        state._studioTestWaiter = (r) => {
          clearTimeout(timer);
          state._studioTestAckId = "";
          resolve(r);
        };
        state._studioLastTestProv = normalizeStudioLlmProvider(pl?.llm?.provider || "");
        let payloadJson = "";
        try {
          const envelope = Object.assign({}, pl, {
            llmProvider: String(flat.llmProvider || pl?.llm?.provider || ""),
            llmApiKey: String(flat.llmApiKey || pl?.llm?.apiKey || ""),
            llmBaseUrl: String(flat.llmBaseUrl || pl?.llm?.baseUrl || ""),
            llmModel: String(flat.llmModel || pl?.llm?.model || "")
          });
          payloadJson = JSON.stringify(envelope);
        } catch (_) {
          clearTimeout(timer);
          state._studioTestWaiter = null;
          state._studioLastTestProv = "";
          state._studioTestAckId = "";
          state._studioTestInFlight = false;
          resolve({ ok: false, error: "配置序列化失败" });
          return;
        }
        state._studioTestInFlight = true;
        setStatus("正在测试 " + (studioLlmPreset(prov).label || prov) + "…", "ok");
        const inline = __SETTINGS_CHILD__ ? null : __settingsStudioTestInline(payloadJson, testId, flat);
        if (inline && inline.type === "testUserStudioLlmResult" && !inline.async) {
          clearTimeout(timer);
          state._studioTestWaiter = null;
          state._studioTestInFlight = false;
          state._studioLastTestProv = "";
          state._studioTestAckId = "";
          const inlineResult = {
            ok: !!inline.ok,
            error: summarizeStudioLlmTestError(inline.error, inline.provider, inline.endpoint, inline.diagnostics, inline),
            elapsedMs: inline.elapsedMs,
            baseUrl: String(inline.baseUrl || "").trim(),
            model: String(inline.model || "").trim(),
            provider: String(inline.provider || "").trim(),
            endpoint: String(inline.endpoint || "").trim(),
            diagnostics: String(inline.diagnostics || "").trim(),
            phase: String(inline.phase || "").trim(),
            status: Number(inline.status || 0)
          };
          if (!inlineResult.ok) setStatus(inlineResult.error, "err");
          else setStatus("连接测试通过", "ok");
          resolve(inlineResult);
          return;
        }
        if (!__settingsAhkHostSync()) {
          /* iframe 内 hostObjects 常不可用，由父壳 settings-bridge relayChildToAhk 同步测试 */
        }
        post({
          type: "testUserStudioLlm",
          testId,
          llmProvider: String(flat.llmProvider || pl?.llm?.provider || ""),
          llmApiKey: String(flat.llmApiKey || pl?.llm?.apiKey || ""),
          llmBaseUrl: String(flat.llmBaseUrl || pl?.llm?.baseUrl || ""),
          llmModel: String(flat.llmModel || pl?.llm?.model || ""),
          payloadJson
        });
      });
    }

    async function runStudioOpenClawImportConnect(opts) {
      opts = opts || {};
      if (studioOpenClawImportRunning) return;
      const btn = opts.fromCard
        ? document.querySelector('.studio-openclaw-import-card[data-prov="openclaw"]')
        : document.getElementById("studioModalOpenClawImport");
      studioOpenClawImportRunning = true;
      if (btn) btn.disabled = true;
      const pid = "openclaw";
      try {
        if (!opts.fromCard && !opts.fromSettingsGrid) {
          const provEl = document.getElementById("studioModalProvider");
          if (provEl && normalizeStudioLlmProvider(provEl.value) !== pid) provEl.value = pid;
          updateStudioModalMinimaxRow(pid);
        } else {
          stashAllStudioCardsFromDom();
        }
        setStatus("正在从本机 OpenClaw 读取配置并检测 Gateway…", "ok");
        post({ type: "invokeAction", op: "syncNiumaChatLlmToStudio" });
        await new Promise((r) => setTimeout(r, 350));
        const stat = await requestStudioOpenClawStatusRefresh(true);
        const token = normalizeStudioApiKey(stat.token || stat.niumaToken || "");
        const source = String(stat.source || "").trim();
        if (!token) {
          throw new Error(
            "未找到 Gateway Token。可设置 OPENCLAW_GATEWAY_TOKEN、在终端执行 openclaw config set gateway.auth.token <值>，或在 Niuma Chat 连接后同步。"
          );
        }
        const pre = studioLlmPreset(pid);
        const baseUrl =
          "http://" + (stat.host || "127.0.0.1") + ":" + (Number(stat.port) || 18789);
        stashStudioApiKeyForProvider(pid, token);
        stashStudioBaseUrlForProvider(pid, baseUrl, false);
        stashStudioModelForProvider(pid, pre.model || "gateway");
        if (!opts.fromCard) {
          const keyEl = document.getElementById("studioModalApiKey");
          if (keyEl) {
            keyEl.value = token;
            keyEl.type = "text";
          }
        } else {
          const card = document.querySelector('.studio-llm-card[data-prov="openclaw"]');
          const keyInp = card?.querySelector(".us-card-key");
          if (keyInp) {
            keyInp.value = token;
            keyInp.type = "text";
          }
        }
        const srcHint = source ? source.replace(/^.*[\\/]/, "") : "本机配置";
        state.studioOpenClawStatus = state.studioOpenClawStatus || {};
        state.studioOpenClawStatus.token = token;
        state.studioOpenClawStatus.source = source;
        state.studioOpenClawStatus.host = stat.host || "127.0.0.1";
        state.studioOpenClawStatus.port = Number(stat.port) || 18789;
        const gwOk = stat.gatewayOk === true;
        state.studioOpenClawStatus.gatewayOk = gwOk;
        state.studioOpenClawStatus.gatewayError = gwOk ? "" : String(stat.gatewayError || "");
        updateStudioOpenClawQuickStatusDom();
        setStatus(
          gwOk
            ? "已导入 Token（" + srcHint + "），Gateway 正常。"
            : "已导入 Token（" + srcHint + "）；Gateway 未响应，请启动本机 openclaw gateway。",
          gwOk ? "ok" : "err"
        );
        const finishSave = function (gatewayOk) {
          if (opts.fromCard || opts.fromSettingsGrid) {
            const list = [...getStudioLlmCardProviders()];
            if (!list.includes(pid)) list.push(pid);
            setStudioLlmCardProviders(list);
            mergeUserStudioState({
              llm: {
                provider: pid,
                apiKey: token,
                baseUrl: baseUrl,
                model: pre.model
              },
              options: {
                llmCardProviders: list,
                llmApiKeys: { ...getStudioLlmApiKeys(), openclaw: token },
                llmBaseUrls: { ...getStudioLlmBaseUrls(), openclaw: baseUrl },
                llmModels: { ...getStudioLlmModels(), openclaw: pre.model }
              }
            });
            render();
            persistStudioCardsNow(false);
            if (gatewayOk) {
              setStatus("OpenClaw 一键连接成功，Gateway 正常。", "ok");
            } else {
              setStatus(
                "Token 已保存到智能定制。Gateway 未响应：请在本机启动 OpenClaw（openclaw gateway / 服务），端口 " +
                  (Number(stat.port) || 18789) +
                  "。",
                "err"
              );
            }
          } else {
            const defEl = document.getElementById("studioModalSetDefault");
            if (defEl && getStudioLlmCardProviders().length === 0) defEl.checked = true;
            confirmStudioLlmAddModal();
            setStatus(
              gatewayOk
                ? "OpenClaw 已导入、检测通过并已保存。"
                : "Token 已保存。Gateway 未响应，请先启动本机 OpenClaw Gateway。",
              gatewayOk ? "ok" : "err"
            );
          }
        };
        finishSave(gwOk);
      } catch (e) {
        setStatus(e?.message || String(e || "连接失败"), "err");
      } finally {
        studioOpenClawImportRunning = false;
        if (btn) btn.disabled = false;
      }
    }

    function bindStudioLlmAddModalOnce() {
      if (studioModalBound) return;
      studioModalBound = true;
      const modal = document.getElementById("studioLlmAddModal");
      const close = () => {
        if (!modal) return;
        modal.classList.remove("open");
        modal.setAttribute("aria-hidden", "true");
      };
      modal?.querySelectorAll("[data-studio-modal-close]").forEach((el) => el.addEventListener("click", close));
      document.getElementById("studioModalCancel")?.addEventListener("click", close);
      document.getElementById("studioModalProvider")?.addEventListener("change", (e) => {
        const pid = normalizeStudioLlmProvider(e.target.value);
        fillStudioLlmModelSelect(pid, studioLlmPreset(pid).model || "", document.getElementById("studioModalModel"));
        updateStudioModalMinimaxRow(pid);
      });
      document.getElementById("studioModalModel")?.addEventListener("change", (e) => {
        if (e.target.value !== "__custom__") return;
        const pid = normalizeStudioLlmProvider(document.getElementById("studioModalProvider")?.value || "openai");
        const inp = document.createElement("input");
        inp.id = "studioModalModel";
        inp.className = "ctl";
        inp.type = "text";
        inp.setAttribute("data-nosave", "1");
        inp.placeholder = "输入模型名称";
        inp.value = studioLlmPreset(pid).model || "";
        e.target.replaceWith(inp);
      });
      document.getElementById("studioModalMinimaxCn")?.addEventListener("click", () => {
        studioModalMinimaxUrl = STUDIO_MINIMAX_BASE_CN;
        setStatus("弹窗内已选国内节点", "ok");
      });
      document.getElementById("studioModalMinimaxIntl")?.addEventListener("click", () => {
        studioModalMinimaxUrl = STUDIO_MINIMAX_BASE_INTL;
        setStatus("弹窗内已选国际节点", "ok");
      });
      document.getElementById("studioModalConfirm")?.addEventListener("click", () => confirmStudioLlmAddModal());
      document.getElementById("studioModalOpenClawImport")?.addEventListener("click", () => runStudioOpenClawImportConnect({ fromCard: false }));
      document.getElementById("studioModalHermesImport")?.addEventListener("click", () => runStudioHermesImportConnect({ fromCard: false }));
      document.addEventListener("keydown", (e) => {
        if (e.key === "Escape" && modal?.classList.contains("open")) close();
      });
    }

    function openStudioLlmAddModal(preferPid) {
      bindStudioLlmAddModalOnce();
      const modal = document.getElementById("studioLlmAddModal");
      if (!modal) return;
      const existing = new Set(getStudioLlmCardProviders());
      const available = Object.keys(STUDIO_LLM_PRESETS).filter((k) => !existing.has(k));
      if (!available.length) {
        setStatus("已添加全部服务商", "err");
        return;
      }
      const sel = document.getElementById("studioModalProvider");
      if (sel) {
        sel.innerHTML = available.map((k) => `<option value="${esc(k)}">${esc(STUDIO_LLM_PRESETS[k].label)}</option>`).join("");
      }
      let pid = normalizeStudioLlmProvider(available[0]);
      preferPid = normalizeStudioLlmProvider(preferPid || "");
      if (preferPid && available.includes(preferPid)) pid = preferPid;
      const keyEl = document.getElementById("studioModalApiKey");
      if (keyEl) keyEl.value = getStudioApiKeyForProvider(pid) || "";
      let modelEl = document.getElementById("studioModalModel");
      if (modelEl && modelEl.tagName !== "SELECT") {
        const nu = document.createElement("select");
        nu.id = "studioModalModel";
        nu.className = "ctl";
        nu.setAttribute("data-nosave", "1");
        modelEl.replaceWith(nu);
        modelEl = nu;
      }
      fillStudioLlmModelSelect(pid, getStudioModelForProvider(pid) || studioLlmPreset(pid).model, modelEl);
      updateStudioModalMinimaxRow(pid);
      const defEl = document.getElementById("studioModalSetDefault");
      if (defEl) defEl.checked = getStudioLlmCardProviders().length === 0;
      modal.classList.add("open");
      modal.setAttribute("aria-hidden", "false");
      if (pid === "openclaw") {
        try {
          post({ type: "openclaw_probe_token" });
        } catch (_) {}
      }
      if (pid === "hermes") {
        try {
          post({ type: "hermes_probe_token" });
        } catch (_) {}
      }
      keyEl?.focus();
    }

    function confirmStudioLlmAddModal() {
      const pid = normalizeStudioLlmProvider(document.getElementById("studioModalProvider")?.value || "");
      if (!pid || !STUDIO_LLM_PRESETS[pid]) return;
      const key = normalizeStudioApiKey(document.getElementById("studioModalApiKey")?.value || "");
      if (pid !== "ollama" && !key) {
        setStatus("请填写 API Key", "err");
        return;
      }
      const modelEl = document.getElementById("studioModalModel");
      let modelVal = String(modelEl?.value || "").trim();
      if (modelVal === "__custom__") modelVal = "";
      const model = resolveStudioModel(pid, modelVal);
      if (pid === "minimax") stashStudioBaseUrlForProvider(pid, studioModalMinimaxUrl, false);
      stashStudioApiKeyForProvider(pid, key);
      stashStudioModelForProvider(pid, model);
      const list = [...getStudioLlmCardProviders()];
      if (!list.includes(pid)) list.push(pid);
      setStudioLlmCardProviders(list);
      const setDefault = !!document.getElementById("studioModalSetDefault")?.checked || list.length === 1;
      const llmPatch = setDefault
        ? {
            provider: pid,
            apiKey: key,
            baseUrl: pid === "minimax" ? studioModalMinimaxUrl : getStudioBaseUrlForProvider(pid),
            model
          }
        : { provider: getActiveStudioLlmProvider() };
      mergeUserStudioState({
        llm: llmPatch,
        options: {
          llmCardProviders: list,
          llmApiKeys: { ...getStudioLlmApiKeys(), ...(key ? { [pid]: key } : {}) },
          llmModels: { ...getStudioLlmModels(), ...(model ? { [pid]: model } : {}) }
        }
      });
      document.getElementById("studioLlmAddModal")?.classList.remove("open");
      document.getElementById("studioLlmAddModal")?.setAttribute("aria-hidden", "true");
      render();
      persistStudioCardsNow(false);
    }

    function buildStudioLlmPersistPayload() {
      if (document.getElementById("studioLlmCards")) stashAllStudioCardsFromDom();
      const keys = { ...getStudioLlmApiKeys() };
      const models = { ...getStudioLlmModels() };
      const cards = [...getStudioLlmCardProviders()];
      const prov = getActiveStudioLlmProvider();
      if (document.getElementById("studioLlmCards")) {
        document.querySelectorAll(".studio-llm-card[data-prov]").forEach((card) => {
          const pid = normalizeStudioLlmProvider(card.dataset.prov || "");
          const keyEl = card.querySelector(".us-card-key");
          if (keyEl) {
            const cur = normalizeStudioApiKey(keyEl.value || "");
            if (cur) keys[pid] = cur;
          }
        });
      }
      return {
        llm: {
          provider: prov,
          apiKey: keys[prov] || "",
          baseUrl: getStudioBaseUrlForProvider(prov),
          model: getStudioModelForProvider(prov)
        },
        paths: { ...(state.data.userStudio?.paths || {}) },
        options: {
          llmApiKeys: keys,
          llmModels: models,
          llmBaseUrls: getStudioLlmBaseUrls(),
          llmManualBaseUrl: getStudioLlmManualFlags(),
          llmCardProviders: cards
        }
      };
    }

    function persistStudioCardsNow(showStatus) {
      const pl = buildStudioLlmPersistPayload();
      markStudioCardsExplicit();
      saveStudioLlmCardsToLocalStorage(pl);
      mergeUserStudioState(pl);
      if (!postStudioLlmSave(pl, !showStatus)) {
        if (showStatus) setStatus("无 API 配置可保存", "err");
        return;
      }
      if (showStatus) setStatus("正在保存大模型配置…", "ok");
    }

    function mergeUserStudioStateFromServer(incoming) {
      if (!incoming || typeof incoming !== "object") return;
      const localCards = getStudioLlmCardProviders();
      const localExplicit = !!state._studioCardsExplicit;
      const incOpt = incoming.options || {};
      const patch = { ...incoming };
      if (localExplicit && !Array.isArray(incOpt.llmCardProviders)) {
        patch.options = { ...incOpt, llmCardProviders: localCards };
      }
      if (Array.isArray(incOpt.llmCardProviders)) {
        state._studioCardsExplicit = true;
      }
      if (incoming.llmUnified && typeof incoming.llmUnified === "object") {
        patch.llmUnified = incoming.llmUnified;
      }
      mergeUserStudioState(patch);
    }

    function removeStudioLlmCard(pid) {
      pid = normalizeStudioLlmProvider(pid);
      stashAllStudioCardsFromDom();
      const list = getStudioLlmCardProviders().filter((p) => p !== pid);
      setStudioLlmCardProviders(list);
      const active = getActiveStudioLlmProvider();
      const nextActive = active === pid ? (list[0] || "openai") : active;
      const llmPatch = list.length
        ? {
            provider: list.includes(nextActive) ? nextActive : list[0],
            apiKey: getStudioApiKeyForProvider(list.includes(nextActive) ? nextActive : list[0]),
            baseUrl: getStudioBaseUrlForProvider(list.includes(nextActive) ? nextActive : list[0]),
            model: getStudioModelForProvider(list.includes(nextActive) ? nextActive : list[0])
          }
        : { provider: "openai", apiKey: "", baseUrl: studioLlmPreset("openai").baseUrl, model: studioLlmPreset("openai").model };
      mergeUserStudioState({
        llm: llmPatch,
        options: { llmCardProviders: list }
      });
      render();
      persistStudioCardsNow(false);
    }

    function runStudioPrimaryLlmTest() {
      const card = document.getElementById("studioPrimaryLlmCard");
      if (!card) return;
      let prov = getPrimaryStudioProvider();
      const pre = studioLlmPreset(prov);
      const g = (id) => document.getElementById(id);
      let apiKey = readStudioPrimaryApiKey(prov);
      const inferred = inferStudioProviderFromApiKey(apiKey);
      if (inferred && inferred !== prov) {
        const prev = prov;
        prov = inferred;
        stashStudioApiKeyForProvider(prov, apiKey);
        if (prov === "minimax" && !getStudioBaseUrlForProvider("minimax")) {
          stashStudioBaseUrlForProvider("minimax", STUDIO_MINIMAX_BASE_CN, false);
        }
        swapStudioPrimaryVendorKeyUi(prev, prov);
        applyStudioPrimaryVendorUi(prov);
        setStatus("已根据密钥格式切换到 " + studioLlmPreset(prov).label + "，正在测试…", "ok");
      }
      apiKey = readStudioPrimaryApiKey(prov) || apiKey;
      const model = resolveStudioModelForVendor(prov, g("usPrimaryModel")?.value || "") || getStudioModelForProvider(prov) || pre.model;
      const baseUrl = readStudioPrimaryBaseUrl(prov) || getStudioBaseUrlForProvider(prov) || pre.baseUrl || "";
      if (prov !== "ollama" && !apiKey) {
        setStatus("未读到 API Key：请确认已粘贴到输入框（sk- 开头），然后重试", "err");
        return;
      }
      stashStudioPrimaryFromDom({ activatePrimary: true });
      const pl = {
        llm: { provider: prov, apiKey, baseUrl, model },
        options: {
          ...(state.data.userStudio?.options || {}),
          llmApiKeys: { ...getStudioLlmApiKeys(), ...(apiKey ? { [prov]: apiKey } : {}) },
          llmModels: { ...getStudioLlmModels(), ...(model ? { [prov]: model } : {}) },
          llmBaseUrls: { ...getStudioLlmBaseUrls(), ...(baseUrl ? { [prov]: baseUrl } : {}) },
          llmManagerEnabled: true
        }
      };
      setStatus("正在测试 " + studioLlmPreset(prov).label + "…", "ok");
      updateStudioPrimaryLlmTestHint("正在测试…", "ok");
      studioTestLlmPromise(pl, { flat: { llmProvider: prov, llmApiKey: apiKey, llmBaseUrl: baseUrl, llmModel: model } }).then((r) => {
        if (r.ok && prov === "minimax") {
          if (r.baseUrl) {
            stashStudioBaseUrlForProvider(prov, r.baseUrl, false);
            const auto = card.querySelector(".studio-url-auto");
            if (auto) auto.textContent = "自动使用官方接口：" + r.baseUrl;
          }
          if (r.model) {
            stashStudioModelForProvider(prov, r.model);
            const modEl = document.getElementById("usPrimaryModel");
            if (modEl) modEl.value = r.model;
          }
          persistStudioLlmToDisk({ silent: true, immediate: true });
        }
        if (r.ok) {
          const okMsg = "连接测试通过" + (r.elapsedMs ? `（${r.elapsedMs}ms）` : "");
          pinStatus(okMsg, "ok");
          updateStudioPrimaryLlmTestHint(okMsg, "ok");
        } else {
          let err = r.error || "连接测试失败";
          if (r.endpoint && !err.includes(r.endpoint)) err += "\n接口: " + r.endpoint;
          pinStatus(err, "err");
          updateStudioPrimaryLlmTestHint(err.split("\n")[0], "err");
        }
        if (state.activeTab === "customize") render();
      });
    }

    function bindStudioPrimaryLlmUi() {
      const card = document.getElementById("studioPrimaryLlmCard");
      if (!card) return;
      state._studioLastUnifiedVendor = getPrimaryStudioProvider();
      ensureStudioLlmDelegatedEvents();
      document.getElementById("usPrimaryBaseManualLink")?.addEventListener("click", (e) => {
        e.preventDefault();
        const prov = getPrimaryStudioProvider();
        const pre = studioLlmPreset(prov);
        card.querySelector(".us-primary-base-auto").style.display = "none";
        card.querySelector(".us-primary-base-manual").style.display = "";
        const inp = document.getElementById("usPrimaryBaseUrl");
        if (inp && !inp.value.trim()) inp.value = getStudioBaseUrlForProvider(prov) || pre.baseUrl || "";
        stashStudioBaseUrlForProvider(prov, inp?.value || "", true);
      });
      ["usPrimaryApiKey", "usPrimaryModel", "usPrimaryBaseUrl"].forEach((id) => {
        document.getElementById(id)?.addEventListener("focusout", () => {
          stashStudioPrimaryFromDom();
          persistStudioLlmToDisk({ silent: true, immediate: true });
        });
      });
      card.querySelector(".us-primary-minimax-cn")?.addEventListener("click", () => {
        setStudioMinimaxRegion(STUDIO_MINIMAX_BASE_CN, "minimax");
      });
      card.querySelector(".us-primary-minimax-intl")?.addEventListener("click", () => {
        setStudioMinimaxRegion(STUDIO_MINIMAX_BASE_INTL, "minimax");
      });
      if (normalizeStudioLlmProvider(getPrimaryStudioProvider()) === "minimax") {
        syncStudioMinimaxRegionUi(getStudioBaseUrlForProvider("minimax") || STUDIO_MINIMAX_BASE_CN);
      }
    }

    function bindStudioLocalGatewayUi() {
      ensureStudioLlmDelegatedEvents();
      updateStudioHermesQuickActionButtons();
      updateStudioOpenClawQuickActionButtons();
      updateStudioHermesRestartBtn();
    }

    function bindStudioLlmCardsUi(activeProv) {
      const cardsRoot = document.getElementById("studioLlmCards");
      if (!cardsRoot) return;
      getStudioLlmCardProviders().forEach((pid) => {
        const modEl = document.getElementById("usLlmModel_" + pid);
        fillStudioLlmModelSelect(pid, getStudioModelForProvider(pid), modEl);
      });
      ensureStudioLlmDelegatedEvents();
      document.getElementById("btnAddStudioLlmCard")?.addEventListener("click", () => openStudioLlmAddModal());
      updateStudioHermesQuickActionButtons();
      updateStudioOpenClawQuickActionButtons();
      updateStudioHermesRestartBtn();
      cardsRoot.querySelectorAll(".studio-llm-remove").forEach((btn) => {
        btn.addEventListener("click", async () => {
          const pid = normalizeStudioLlmProvider(btn.dataset.prov || "");
          const ok = await (window.nmConfirm ? window.nmConfirm(
            "移除卡片？",
            "确定移除「" + studioLlmPreset(pid).label + "」卡片？密钥分槽仍保留，可再次添加。",
            { okLabel: "移除", cancelLabel: "取消", danger: true }
          ) : Promise.resolve(confirm("确定移除「" + studioLlmPreset(pid).label + "」卡片？密钥分槽仍保留，可再次添加。")));
          if (!ok) return;
          removeStudioLlmCard(pid);
        });
      });
      cardsRoot.querySelectorAll(".studio-llm-test-card").forEach((btn) => {
        btn.addEventListener("click", () => testStudioLlmCard(btn.dataset.prov));
      });
      cardsRoot.querySelectorAll(".studio-openclaw-import-card").forEach((btn) => {
        btn.addEventListener("click", () => runStudioOpenClawImportConnect({ fromCard: true }));
      });
      cardsRoot.querySelectorAll(".studio-hermes-import-card").forEach((btn) => {
        btn.addEventListener("click", () => runStudioHermesImportConnect({ fromCard: true }));
      });
      cardsRoot.querySelectorAll(".us-card-manual-link").forEach((link) => {
        link.addEventListener("click", (e) => {
          e.preventDefault();
          const pid = normalizeStudioLlmProvider(link.dataset.prov || "");
          const card = link.closest(".studio-llm-card");
          if (!card) return;
          card.dataset.manualBase = "1";
          const autoRow = card.querySelector(".us-card-base-auto");
          const manualRow = card.querySelector(".us-card-base-manual");
          const manualInp = card.querySelector(".us-card-base-manual-input");
          if (autoRow) autoRow.style.display = "none";
          if (manualRow) manualRow.style.display = "";
          if (manualInp && !manualInp.value.trim())
            manualInp.value = getStudioBaseUrlForProvider(pid) || studioLlmPreset(pid).baseUrl || "";
          stashStudioBaseUrlForProvider(pid, manualInp?.value || "", true);
        });
      });
      cardsRoot.querySelectorAll(".us-minimax-cn").forEach((btn) => {
        btn.addEventListener("click", () => setStudioMinimaxRegion(STUDIO_MINIMAX_BASE_CN, btn.dataset.prov));
      });
      cardsRoot.querySelectorAll(".us-minimax-intl").forEach((btn) => {
        btn.addEventListener("click", () => setStudioMinimaxRegion(STUDIO_MINIMAX_BASE_INTL, btn.dataset.prov));
      });
      cardsRoot.querySelectorAll(".us-card-model").forEach((modEl) => {
        if (modEl.tagName !== "SELECT") return;
        modEl.addEventListener("change", () => {
          if (modEl.value !== "__custom__") return;
          const pid = normalizeStudioLlmProvider(modEl.dataset.prov || "");
          const inp = document.createElement("input");
          inp.id = modEl.id;
          inp.className = modEl.className;
          inp.type = "text";
          inp.dataset.prov = pid;
          inp.setAttribute("data-nosave", "1");
          inp.placeholder = "输入模型名称";
          inp.value = studioLlmPreset(pid).model || "";
          modEl.replaceWith(inp);
        });
      });
      document.querySelectorAll('input[name="usLlmActiveProvider"]').forEach((radio) => {
        radio.addEventListener("change", () => {
          if (!radio.checked) return;
          const pid = normalizeStudioLlmProvider(radio.value);
          stashAllStudioCardsFromDom();
          mergeUserStudioState({
            llm: {
              provider: pid,
              apiKey: getStudioApiKeyForProvider(pid),
              baseUrl: getStudioBaseUrlForProvider(pid),
              model: getStudioModelForProvider(pid)
            }
          });
          document.querySelectorAll(".studio-llm-card").forEach((c) => {
            c.classList.toggle("is-default", normalizeStudioLlmProvider(c.dataset.prov) === pid);
          });
          persistStudioCardsNow(false);
        });
      });
    }

    function buildStudioLlmPayloadForProvider(pid) {
      pid = normalizeStudioLlmProvider(pid);
      stashAllStudioCardsFromDom();
      const pl = collectUserStudioPayload();
      const keys = { ...getStudioLlmApiKeys() };
      const apiKey = readStudioCardApiKey(pid) || keys[pid] || "";
      if (apiKey) keys[pid] = apiKey;
      return {
        ...pl,
        llm: {
          provider: pid,
          apiKey,
          baseUrl: getStudioBaseUrlForProvider(pid),
          model: getStudioModelForProvider(pid)
        },
        options: {
          ...(pl.options || {}),
          llmApiKeys: keys
        }
      };
    }

    function testStudioLlmCard(pid) {
      const now = Date.now();
      if (state._studioTestInFlight) {
        setStatus("API 测试进行中，请稍候…", "ok");
        return;
      }
      if (state._studioTestLastAt && now - state._studioTestLastAt < 12000) {
        const waitSec = Math.ceil((12000 - (now - state._studioTestLastAt)) / 1000);
        setStatus(`测试过于频繁，请 ${waitSec} 秒后再试`, "err");
        return;
      }
      pid = normalizeStudioLlmProvider(pid);
      const apiKey = readStudioCardApiKey(pid);
      const pl = buildStudioLlmPayloadForProvider(pid);
      if (apiKey) {
        pl.llm.apiKey = apiKey;
        if (!pl.options) pl.options = {};
        pl.options.llmApiKeys = { ...(pl.options.llmApiKeys || getStudioLlmApiKeys()), [pid]: apiKey };
      }
      const testKey = String(pl.llm?.apiKey || "").trim();
      if (pid !== "ollama" && !testKey) {
        setStatus("未读到 API Key：请确认已粘贴到卡片输入框", "err");
        return;
      }
      state._studioTestLastAt = now;
      setStatus("正在测试 " + studioLlmPreset(pid).label + "…", "ok");
      studioTestLlmPromise(pl, {
        flat: {
          llmProvider: pid,
          llmApiKey: testKey,
          llmBaseUrl: pl.llm?.baseUrl || "",
          llmModel: pl.llm?.model || ""
        }
      }).then((r) => {
        state._studioTestInFlight = false;
        if (r.ok) setStatus("连接测试通过", "ok");
        else {
          let err = r.error || "连接测试失败";
          if (r.endpoint && !err.includes(r.endpoint)) err += " · " + r.endpoint;
          setStatus(err, "err");
        }
        if (state.activeTab === "customize") render();
      });
    }

    function bindStudioLlmUi(llm, opts) {
      const provEl = document.getElementById("usLlmProvider");
      if (!provEl) return;
      provEl.value = normalizeStudioLlmProvider(llm?.provider);
      const initPid = provEl.value;
      state._studioManualBaseUrl = isStudioManualBaseUrlFor(initPid);
      const initUrls = getStudioLlmBaseUrls();
      const legacyBu = String(llm?.baseUrl || "").trim();
      if (legacyBu && studioBaseUrlMatchesProvider(initPid, legacyBu) && !initUrls[initPid]) {
        initUrls[initPid] = legacyBu;
        if (!state.data.userStudio) state.data.userStudio = { options: {} };
        if (!state.data.userStudio.options) state.data.userStudio.options = {};
        state.data.userStudio.options.llmBaseUrls = initUrls;
      }
      const initKeys = getStudioLlmApiKeys();
      const legacyKey = normalizeStudioApiKey(llm?.apiKey || "");
      const legacyProv = normalizeStudioLlmProvider(llm?.provider || initPid);
      if (legacyKey && !initKeys[legacyProv]) {
        initKeys[legacyProv] = legacyKey;
        if (!state.data.userStudio) state.data.userStudio = { options: {} };
        if (!state.data.userStudio.options) state.data.userStudio.options = {};
        state.data.userStudio.options.llmApiKeys = initKeys;
      }
      state._studioLastProv = normalizeStudioLlmProvider(provEl.value);
      ensureStudioLlmDelegatedEvents();
      applyStudioLlmPresetUi(true);
      const savedModel = String(llm?.model || "").trim();
      if (savedModel) fillStudioLlmModelSelect(provEl.value, savedModel);
      const manualLink = document.getElementById("usLlmBaseUrlManualLink");
      if (manualLink) {
        manualLink.addEventListener("click", (e) => {
          e.preventDefault();
          const pid = normalizeStudioLlmProvider(provEl.value);
          state._studioManualBaseUrl = true;
          const manualInp = document.getElementById("usLlmBaseUrlManual");
          if (manualInp && !manualInp.value.trim())
            manualInp.value = getStudioBaseUrlForProvider(pid) || studioLlmPreset(pid).baseUrl || "";
          applyStudioLlmPresetUi(true);
        });
      }
      document.getElementById("usMinimaxRegionCn")?.addEventListener("click", () => setStudioMinimaxRegion(STUDIO_MINIMAX_BASE_CN));
      document.getElementById("usMinimaxRegionIntl")?.addEventListener("click", () => setStudioMinimaxRegion(STUDIO_MINIMAX_BASE_INTL));
      const modEl = document.getElementById("usLlmModel");
      if (modEl && modEl.tagName === "SELECT") {
        modEl.addEventListener("change", () => {
          if (modEl.value === "__custom__") {
            const pid = normalizeStudioLlmProvider(provEl.value);
            const inp = document.createElement("input");
            inp.id = "usLlmModel";
            inp.className = "ctl";
            inp.type = "text";
            inp.setAttribute("data-nosave", "1");
            inp.placeholder = "输入模型名称";
            inp.value = studioLlmPreset(pid).model || "";
            modEl.replaceWith(inp);
          }
        });
      }
    }

    function collectUserStudioPayload() {
      if (document.getElementById("studioPrimaryLlmCard")) {
        stashStudioPrimaryFromDom();
      } else if (document.getElementById("studioLlmCards")) {
        stashAllStudioCardsFromDom();
      } else {
        stashStudioApiKeyFromDom();
        stashStudioBaseUrlFromDom();
      }
      const g = (id) => document.getElementById(id);
      let prov = getActiveStudioLlmProvider();
      if (document.getElementById("studioPrimaryLlmCard")) {
        prov = getPrimaryStudioProvider();
      } else if (!document.getElementById("studioLlmCards")) {
        prov = normalizeStudioLlmProvider(g("usLlmProvider")?.value || prov);
      }
      const keys = { ...getStudioLlmApiKeys() };
      if (document.getElementById("studioPrimaryLlmCard")) {
        const pre = studioLlmPreset(prov);
        const curKey = normalizeStudioApiKey(g("usPrimaryApiKey")?.value || "") || keys[prov] || "";
        if (curKey) keys[prov] = curKey;
        const baseUrls = { ...getStudioLlmBaseUrls() };
        const manualFlags = { ...getStudioLlmManualFlags() };
        const manualRow = document.querySelector(".us-primary-base-manual");
        const manualOn = manualRow && manualRow.style.display !== "none";
        let curBase = getStudioBaseUrlForProvider(prov) || pre.baseUrl || "";
        if (manualOn) {
          curBase = String(g("usPrimaryBaseUrl")?.value || "").trim();
          if (curBase) baseUrls[prov] = curBase;
          manualFlags[prov] = true;
        } else {
          delete manualFlags[prov];
        }
        const modelVal = resolveStudioModelForVendor(prov, g("usPrimaryModel")?.value || "");
        const models = { ...getStudioLlmModels() };
        if (modelVal) models[prov] = modelVal;
        const optKeep = state.data.userStudio?.options || {};
        return {
          llm: {
            provider: prov,
            apiKey: curKey,
            baseUrl: curBase,
            model: modelVal || pre.model || ""
          },
          paths: {
            cursor: (g("usPath_cursor")?.value || "").trim(),
            autohotkey: (g("usPath_autohotkey")?.value || "").trim(),
            everything: (g("usPath_everything")?.value || "").trim(),
            python: (g("usPath_python")?.value || "").trim(),
            notes: (g("usPathNotes")?.value || "").trim()
          },
          options: {
            ...optKeep,
            llmApiKeys: keys,
            llmBaseUrls: baseUrls,
            llmManualBaseUrl: manualFlags,
            llmModels: models,
            llmCardProviders: [prov],
            llmManagerEnabled: true
          }
        };
      }
      if (!document.getElementById("studioLlmCards")) {
        let modelVal = (g("usLlmModel")?.value || "").trim();
        if (modelVal === "__custom__") modelVal = "";
        const curKey = normalizeStudioApiKey(g("usLlmApiKey")?.value || "") || keys[prov] || "";
        if (curKey) keys[prov] = curKey;
        const baseUrls = getStudioLlmBaseUrls();
        const manualFlags = getStudioLlmManualFlags();
        const curBase = resolveStudioBaseUrl(
          prov,
          state._studioManualBaseUrl ? g("usLlmBaseUrlManual")?.value : "",
          !!state._studioManualBaseUrl
        );
        if (curBase && studioBaseUrlMatchesProvider(prov, curBase)) baseUrls[prov] = curBase;
        if (state._studioManualBaseUrl) manualFlags[prov] = true;
        else delete manualFlags[prov];
        return {
          llm: {
            provider: prov,
            apiKey: curKey,
            baseUrl: curBase,
            model: resolveStudioModel(prov, modelVal)
          },
          paths: {
            cursor: (g("usPath_cursor")?.value || "").trim(),
            autohotkey: (g("usPath_autohotkey")?.value || "").trim(),
            everything: (g("usPath_everything")?.value || "").trim(),
            python: (g("usPath_python")?.value || "").trim(),
            notes: (g("usPathNotes")?.value || "").trim()
          },
          options: {
            ...(state.data.userStudio?.options || {}),
            llmApiKeys: keys,
            llmBaseUrls: baseUrls,
            llmManualBaseUrl: manualFlags,
            llmModels: getStudioLlmModels(),
            llmCardProviders: getStudioLlmCardProviders(),
            manualBaseUrl: !!state._studioManualBaseUrl,
            niumaAutoInjectContext: !!document.getElementById("niumaAutoInjectContext")?.checked,
            niumaSystemPrompt: String(document.getElementById("studioNiumaSystemPrompt")?.value || "").trim(),
            niumaInstallRoot: String(document.getElementById("niumaInstallRoot")?.value || "").trim(),
            llmManagerEnabled: readLlmManagerEnabledFromDom()
          }
        };
      }
      const models = { ...getStudioLlmModels() };
      const baseUrls = { ...getStudioLlmBaseUrls() };
      const manualFlags = { ...getStudioLlmManualFlags() };
      const curKey = keys[prov] || "";
      const curBase = getStudioBaseUrlForProvider(prov);
      const curModel = getStudioModelForProvider(prov);
      return {
        llm: {
          provider: prov,
          apiKey: curKey,
          baseUrl: curBase,
          model: curModel
        },
        paths: {
          cursor: (g("usPath_cursor")?.value || "").trim(),
          autohotkey: (g("usPath_autohotkey")?.value || "").trim(),
          everything: (g("usPath_everything")?.value || "").trim(),
          python: (g("usPath_python")?.value || "").trim(),
          notes: (g("usPathNotes")?.value || "").trim()
        },
        options: {
          ...(state.data.userStudio?.options || {}),
          llmApiKeys: keys,
          llmBaseUrls: baseUrls,
          llmManualBaseUrl: manualFlags,
          llmModels: models,
          llmCardProviders: getStudioLlmCardProviders(),
          niumaAutoInjectContext: !!document.getElementById("niumaAutoInjectContext")?.checked,
          niumaSystemPrompt: String(document.getElementById("studioNiumaSystemPrompt")?.value || "").trim(),
          niumaInstallRoot: String(document.getElementById("niumaInstallRoot")?.value || "").trim(),
          llmManagerEnabled: readLlmManagerEnabledFromDom()
        }
      };
    }

    function mergeStudioSlotObject(prevObj, nextObj, normalizeKey, normalizeVal) {
      const out = {};
      const ingest = (src) => {
        if (!src || typeof src !== "object" || Array.isArray(src)) return;
        Object.keys(src).forEach((k) => {
          const nk = normalizeKey(k);
          const v = normalizeVal(src[k], nk);
          if (v !== "" && v != null) out[nk] = v;
        });
      };
      ingest(prevObj);
      ingest(nextObj);
      return out;
    }

    function mergeUserStudioState(pl) {
      if (!pl || typeof pl !== "object") return;
      const prev = state.data.userStudio || {};
      const prevOpt = prev.options || {};
      const plOpt = pl.options || {};
      const mergedKeys = mergeStudioSlotObject(
        prevOpt.llmApiKeys,
        plOpt.llmApiKeys,
        normalizeStudioLlmProvider,
        (v) => normalizeStudioApiKey(v)
      );
      const mergedBaseUrls = mergeStudioSlotObject(
        prevOpt.llmBaseUrls,
        plOpt.llmBaseUrls,
        normalizeStudioLlmProvider,
        (v, nk) => {
          const u = String(v || "").trim();
          return u && studioBaseUrlMatchesProvider(nk, u) ? u : "";
        }
      );
      const mergedModels = mergeStudioSlotObject(
        prevOpt.llmModels,
        plOpt.llmModels,
        normalizeStudioLlmProvider,
        (v) => String(v || "").trim()
      );
      let cardProviders = null;
      if (Array.isArray(prevOpt.llmCardProviders))
        cardProviders = prevOpt.llmCardProviders.map(normalizeStudioLlmProvider).filter((p, i, arr) => STUDIO_LLM_PRESETS[p] && arr.indexOf(p) === i);
      if (Array.isArray(plOpt.llmCardProviders))
        cardProviders = plOpt.llmCardProviders.map(normalizeStudioLlmProvider).filter((p, i, arr) => STUDIO_LLM_PRESETS[p] && arr.indexOf(p) === i);
      const mergedManual = { ...getStudioLlmManualFlags() };
      if (plOpt.llmManualBaseUrl && typeof plOpt.llmManualBaseUrl === "object") {
        Object.keys(plOpt.llmManualBaseUrl).forEach((k) => {
          const nk = normalizeStudioLlmProvider(k);
          if (plOpt.llmManualBaseUrl[k]) mergedManual[nk] = true;
          else delete mergedManual[nk];
        });
      }
      const mergedLlm = { ...(prev.llm || {}), ...(pl.llm || {}) };
      const prov = normalizeStudioLlmProvider(mergedLlm.provider || "openai");
      const prevProv = normalizeStudioLlmProvider(prev.llm?.provider || prov);
      const slotKey = mergedKeys[prov] || "";
      if (slotKey) {
        mergedLlm.apiKey = slotKey;
      } else {
        const rawKey = normalizeStudioApiKey(mergedLlm.apiKey || "");
        if (rawKey && prevProv === prov) {
          mergedKeys[prov] = rawKey;
          mergedLlm.apiKey = rawKey;
        } else {
          mergedLlm.apiKey = "";
        }
      }
      if (Array.isArray(plOpt.llmCardProviders) || state._studioCardsExplicit)
        markStudioCardsExplicit();
      const mergedOptions = {
        ...prevOpt,
        ...plOpt,
        llmApiKeys: mergedKeys,
        llmBaseUrls: mergedBaseUrls,
        llmManualBaseUrl: mergedManual,
        llmModels: mergedModels
      };
      if (cardProviders !== null)
        mergedOptions.llmCardProviders = cardProviders;
      state.data.userStudio = {
        ...prev,
        ...pl,
        llm: mergedLlm,
        paths: { ...(prev.paths || {}), ...(pl.paths || {}) },
        options: mergedOptions
      };
      try {
        sessionStorage.setItem("niuma_studio_llm_draft", JSON.stringify(state.data.userStudio));
      } catch (_) {}
    }

    function onStudioLlmProviderChange() {
      const provEl = document.getElementById("usLlmProvider");
      const keyEl = document.getElementById("usLlmApiKey");
      if (!provEl) return;
      if (keyEl && state._studioLastProv)
        stashStudioApiKeyForProvider(state._studioLastProv, keyEl.value);
      stashStudioBaseUrlFromDom();
      const nextPid = normalizeStudioLlmProvider(provEl.value);
      state._studioManualBaseUrl = isStudioManualBaseUrlFor(nextPid);
      state._studioLastProv = nextPid;
      mergeUserStudioState({ llm: { provider: nextPid, apiKey: getStudioApiKeyForProvider(nextPid) } });
      applyStudioLlmPresetUi(false);
    }

    let studioLlmPersistTimer = 0;
    let studioLlmPersistInFlight = false;
    let studioLlmPersistQueued = false;

    function buildStudioLlmSavePayloadFromState() {
      const us = state.data.userStudio || {};
      const llm = { ...(us.llm || {}) };
      const keys = { ...getStudioLlmApiKeys() };
      const prov = normalizeStudioLlmProvider(llm.provider || "openai");
      if (keys[prov]) llm.apiKey = keys[prov];
      else llm.apiKey = normalizeStudioApiKey(llm.apiKey || "");
      llm.provider = prov;
      llm.baseUrl = getStudioBaseUrlForProvider(prov);
      llm.model = getStudioModelForProvider(prov);
      return {
        llm,
        paths: { ...(us.paths || {}) },
        options: {
          ...(us.options || {}),
          llmApiKeys: keys,
          llmBaseUrls: getStudioLlmBaseUrls(),
          llmManualBaseUrl: getStudioLlmManualFlags(),
          llmModels: getStudioLlmModels(),
          llmCardProviders: getStudioLlmCardProviders()
        }
      };
    }

    function buildStudioLlmSavePayload() {
      if (document.getElementById("studioPrimaryLlmCard")) {
        return collectUserStudioPayload();
      }
      if (document.getElementById("studioLlmCards") || document.getElementById("usLlmApiKey")) {
        if (document.getElementById("studioLlmCards")) stashAllStudioCardsFromDom();
        else {
          stashStudioApiKeyFromDom();
          stashStudioBaseUrlFromDom();
        }
        return collectUserStudioPayload();
      }
      return buildStudioLlmSavePayloadFromState();
    }

    function shouldPersistStudioLlmPayload(pl) {
      if (state._studioCardsExplicit) return true;
      const prov = normalizeStudioLlmProvider(pl?.llm?.provider);
      const keys = pl?.options?.llmApiKeys || {};
      const hasAnyKey = Object.keys(keys).some((k) => normalizeStudioApiKey(keys[k]));
      const curKey = normalizeStudioApiKey(pl?.llm?.apiKey || "");
      return prov === "ollama" || !!curKey || hasAnyKey || Array.isArray(pl?.options?.llmCardProviders);
    }

    function postStudioLlmSave(pl, silent) {
      if (!shouldPersistStudioLlmPayload(pl)) return false;
      markStudioCardsExplicit();
      mergeUserStudioState(pl);
      saveStudioLlmCardsToLocalStorage(pl);
      state._studioLlmPersistSilent = !!silent;
      studioLlmPersistInFlight = true;
      let payloadJson = "";
      try { payloadJson = JSON.stringify(pl); } catch (_) {}
      post({ type: "saveUserStudio", payloadJson });
      return true;
    }

    function flushStudioLlmPending() {
      if (studioLlmPersistTimer) {
        clearTimeout(studioLlmPersistTimer);
        studioLlmPersistTimer = 0;
      }
      const pl = buildStudioLlmSavePayload();
      if (!shouldPersistStudioLlmPayload(pl)) return;
      if (studioLlmPersistInFlight) {
        studioLlmPersistQueued = true;
        return;
      }
      postStudioLlmSave(pl, true);
    }

    function persistStudioLlmToDisk(options = {}) {
      const { silent = true, immediate = false } = options;
      const run = () => {
        studioLlmPersistTimer = 0;
        const pl = buildStudioLlmSavePayload();
        if (!shouldPersistStudioLlmPayload(pl)) return;
        if (studioLlmPersistInFlight) {
          studioLlmPersistQueued = true;
          return;
        }
        if (postStudioLlmSave(pl, silent) && !silent) setStatus("正在保存 API 配置…", "ok");
      };
      if (immediate) {
        if (studioLlmPersistTimer) {
          clearTimeout(studioLlmPersistTimer);
          studioLlmPersistTimer = 0;
        }
        run();
        return;
      }
      if (studioLlmPersistTimer) clearTimeout(studioLlmPersistTimer);
      studioLlmPersistTimer = setTimeout(run, 400);
    }

    function leaveActiveTab(tabId) {
      if (tabId === "hotkeys") {
        stopHotkeyRecording();
        destroyFtbWorkbenchSortable();
        destroyMenuWorkbenchSortable();
      }
      if (tabId === "appearance") {
        captureAppearanceTabState();
        flushHoleSettingsSaveNow();
        postSavePopupScreen();
        return;
      }
      if (tabId === "customize") {
        captureCustomizeTabState();
        flushStudioLlmPending();
        return;
      }
      if (tabId === "general") {
        captureGeneralTabState();
        flushSettingsTab();
        return;
      }
      try {
        state.data = readFromUI();
      } catch (_) {}
      scheduleSettingsPersist(true);
    }

    window.flushStudioLlmPending = flushStudioLlmPending;
    window.__nmerFlushStudioLlm = flushStudioLlmPending;

    function ensureStudioLlmDelegatedEvents() {
      if (state._studioLlmDelegated) return;
      const panel = document.getElementById("panel");
      if (!panel) return;
      state._studioLlmDelegated = true;
      panel.addEventListener("click", (e) => {
        const t = e.target && e.target.closest ? e.target.closest("button") : null;
        if (!t) return;
        if (t.id === "btnStudioHermesQuickTest") {
          e.preventDefault();
          studioHermesQuickTest();
          return;
        }
        if (t.id === "btnStudioHermesQuickConfirm") {
          e.preventDefault();
          studioHermesQuickConfirm();
          return;
        }
        if (t.id === "btnStudioHermesQuickRestart") {
          e.preventDefault();
          studioHermesQuickRestartGateway();
          return;
        }
        if (t.id === "btnStudioOpenClawQuickTest") {
          e.preventDefault();
          studioOpenClawQuickTest();
          return;
        }
        if (t.id === "btnStudioOpenClawQuickConfirm") {
          e.preventDefault();
          studioOpenClawQuickConfirm();
          return;
        }
        if (t.id === "btnStudioPrimaryLlmTest") {
          e.preventDefault();
          runStudioPrimaryLlmTest();
          return;
        }
      });
      panel.addEventListener("change", (e) => {
        if (e.target?.id === "usLlmProvider") onStudioLlmProviderChange();
        if (e.target?.id === "usLlmProtocolId" || e.target?.id === "usLlmUnifiedVendor") {
          if (e.target?.id === "usLlmUnifiedVendor") {
            const newVendor = normalizeStudioLlmProvider(e.target.value);
            const prev = state._studioLastUnifiedVendor
              || studioPrimaryVendorFromState(state.data.userStudio || {});
            if (prev && prev !== newVendor) {
              swapStudioPrimaryVendorKeyUi(prev, newVendor);
            }
            state._studioLastUnifiedVendor = newVendor;
            applyStudioPrimaryVendorUi(newVendor);
          }
          applyStudioPrimaryFromDom();
          captureCustomizeTabState();
          persistStudioLlmToDisk({ silent: true, immediate: true });
          if (state.activeTab === "customize") render();
        }
      });
      panel.addEventListener("paste", (e) => {
        const t = e.target;
        if (t?.id === "usPrimaryApiKey") {
          setTimeout(() => {
            const key = normalizeStudioApiKey(t.value || "");
            const prov = getPrimaryStudioProvider();
            if (key) stashStudioApiKeyForProvider(prov, key);
            const inferred = inferStudioProviderFromApiKey(key);
            if (inferred && inferred !== prov) {
              stashStudioApiKeyForProvider(inferred, key);
              swapStudioPrimaryVendorKeyUi(prov, inferred);
              applyStudioPrimaryVendorUi(inferred);
              setStatus("已识别为 " + studioLlmPreset(inferred).label + " 密钥，已切换厂商", "ok");
            }
          }, 0);
        }
      });
      panel.addEventListener("input", (e) => {
        const t = e.target;
        if (t?.id === "usPrimaryApiKey") {
          const key = normalizeStudioApiKey(t.value || "");
          const prov = getPrimaryStudioProvider();
          stashStudioApiKeyForProvider(prov, key);
          const inferred = inferStudioProviderFromApiKey(key);
          if (inferred && inferred !== prov && key.length >= 12) {
            stashStudioApiKeyForProvider(inferred, key);
            applyStudioPrimaryVendorUi(inferred);
          }
          return;
        }
        if (t?.classList?.contains("us-card-key")) {
          stashStudioApiKeyForProvider(t.dataset.prov || "", t.value);
          return;
        }
        if (t?.id !== "usLlmApiKey") return;
        const provEl = document.getElementById("usLlmProvider");
        if (provEl) stashStudioApiKeyForProvider(provEl.value, t.value);
      });
      panel.addEventListener("focusout", (e) => {
        const t = e.target;
        if (t?.id === "usPrimaryApiKey" || t?.id === "usPrimaryModel" || t?.id === "usPrimaryBaseUrl") {
          captureCustomizeTabState();
          persistStudioLlmToDisk({ silent: true, immediate: true });
          return;
        }
        if (t?.classList?.contains("us-card-key") || t?.classList?.contains("us-card-base-manual-input") || t?.classList?.contains("us-card-model")) {
          captureCustomizeTabState();
          persistStudioLlmToDisk({ silent: true, immediate: true });
          return;
        }
        if (t?.id !== "usLlmApiKey") return;
        captureCustomizeTabState();
        flushStudioLlmPending();
      });
    }

    /** 离开智能定制标签前：先把表单写入内存（落盘由 leaveActiveTab / blur / 关闭时触发） */
    function captureCustomizeTabState() {
      if (document.getElementById("studioPrimaryLlmCard")) {
        stashStudioPrimaryFromDom();
        mergeUserStudioState(collectUserStudioPayload());
        return;
      }
      if (document.getElementById("studioLlmCards")) {
        stashAllStudioCardsFromDom();
        mergeUserStudioState(collectUserStudioPayload());
        return;
      }
      if (!document.getElementById("usLlmApiKey")) return;
      stashStudioApiKeyFromDom();
      stashStudioBaseUrlFromDom();
      mergeUserStudioState(collectUserStudioPayload());
    }

    function readCustomize(d) {
      if (!document.getElementById("studioPrimaryLlmCard") && !document.getElementById("studioLlmCards") && !document.getElementById("usLlmApiKey")) return d;
      const pl = collectUserStudioPayload();
      mergeUserStudioState(pl);
      d.userStudio = state.data.userStudio;
      return d;
    }

    function restoreStudioLlmDraftIfNeeded() {
      if (state._studioCardsExplicit) return;
      const opt = state.data.userStudio?.options || {};
      if (Array.isArray(opt.llmCardProviders)) return;
      const keys = getStudioLlmApiKeys();
      const hasSlots = Object.keys(keys).length > 0;
      const cur = state.data.userStudio?.llm || {};
      if (hasSlots || String(cur.apiKey || "").trim()) return;
      try {
        const raw = sessionStorage.getItem("niuma_studio_llm_draft");
        if (!raw) return;
        const draft = JSON.parse(raw);
        if (draft && typeof draft === "object") mergeUserStudioState(draft);
      } catch (_) {}
    }
    function csvToArr(v){ return String(v || "").split(",").map(s => s.trim()).filter(Boolean); }
    function arrToCsv(arr){ return (arr || []).join(","); }
    function readSearch(d){
      const selectedDefault = Array.from(document.querySelectorAll('[data-engine-target="default"]:checked')).map(el => el.value);
      const selectedAiCli = Array.from(document.querySelectorAll('[data-engine-target="ai-cli"]:checked')).map(el => el.value);
      d.searchEngine = arrToCsv(selectedDefault);
      d.voiceSearchSelectedEnginesCsv = arrToCsv(selectedAiCli);
      d.autoLoadSelectedText = !!document.getElementById("autoLoadSelectedText")?.checked;
      d.autoUpdateVoiceInput = !!document.getElementById("autoUpdateVoiceInput")?.checked;
      const cats = [];
      ALL_CATEGORIES.forEach(c => { if (document.getElementById("cat_" + c)?.checked) cats.push(c); });
      d.voiceSearchEnabledCategories = cats;
      return d;
    }
    function readScreenshot(d) {
      const base = { ...(d.screenshotConfig || {}) };
      const pickChecked = (id, fallback=false) => {
        const el = document.getElementById(id);
        return el ? !!el.checked : !!fallback;
      };
      base.captureMode = document.getElementById("ssCaptureMode")?.value || base.captureMode || "selection";
      base.outputTarget = document.getElementById("ssOutputTarget")?.value || base.outputTarget || "editor";
      base.includeCursor = pickChecked("ssIncludeCursor", base.includeCursor);
      base.autoCopyClipboard = pickChecked("ssAutoCopyClipboard", base.autoCopyClipboard);
      base.scalePercent = Number(document.getElementById("ssScalePercent")?.value || base.scalePercent || 100);
      base.imageFormat = document.getElementById("ssImageFormat")?.value || base.imageFormat || "png";
      base.jpegQuality = Number(document.getElementById("ssJpegQuality")?.value || base.jpegQuality || 90);
      base.saveFilenamePattern = (document.getElementById("ssFilenamePattern")?.value || base.saveFilenamePattern || "Screenshot_{yyyyMMdd_HHmmss}").trim();
      base.ocrEnhanceEnabled = pickChecked("ssOcrEnhanceEnabled", base.ocrEnhanceEnabled !== false);
      base.ocrScalePrimary = Number(document.getElementById("ssOcrScalePrimary")?.value || base.ocrScalePrimary || 150);
      base.ocrScaleSecondary = Number(document.getElementById("ssOcrScaleSecondary")?.value || base.ocrScaleSecondary || 200);
      base.ocrUseGrayscale = pickChecked("ssOcrUseGrayscale", base.ocrUseGrayscale !== false);
      base.ocrMonochromeLow = Number(document.getElementById("ssOcrMonoLow")?.value || base.ocrMonochromeLow || 160);
      base.ocrMonochromeHigh = Number(document.getElementById("ssOcrMonoHigh")?.value || base.ocrMonochromeHigh || 175);
      base.ocrUseInvert = pickChecked("ssOcrUseInvert", base.ocrUseInvert !== false);
      base.ocrTextLayoutMode = document.getElementById("ssOcrLayout")?.value || base.ocrTextLayoutMode || "keep";
      base.ocrPunctuationMode = document.getElementById("ssOcrPunc")?.value || base.ocrPunctuationMode || "keep";
      base.ocrDirectCopyEnabled = pickChecked("ssOcrDirectCopy", base.ocrDirectCopyEnabled);
      if (!Number.isFinite(base.scalePercent) || base.scalePercent < 25) base.scalePercent = 25;
      if (base.scalePercent > 300) base.scalePercent = 300;
      if (!Number.isFinite(base.jpegQuality) || base.jpegQuality < 10) base.jpegQuality = 10;
      if (base.jpegQuality > 100) base.jpegQuality = 100;
      if (!Number.isFinite(base.ocrScalePrimary) || base.ocrScalePrimary < 100) base.ocrScalePrimary = 100;
      if (base.ocrScalePrimary > 300) base.ocrScalePrimary = 300;
      if (!Number.isFinite(base.ocrScaleSecondary) || base.ocrScaleSecondary < 100) base.ocrScaleSecondary = 100;
      if (base.ocrScaleSecondary > 300) base.ocrScaleSecondary = 300;
      if (!Number.isFinite(base.ocrMonochromeLow) || base.ocrMonochromeLow < 0) base.ocrMonochromeLow = 0;
      if (base.ocrMonochromeLow > 255) base.ocrMonochromeLow = 255;
      if (!Number.isFinite(base.ocrMonochromeHigh) || base.ocrMonochromeHigh < 0) base.ocrMonochromeHigh = 0;
      if (base.ocrMonochromeHigh > 255) base.ocrMonochromeHigh = 255;
      if (base.ocrMonochromeHigh < base.ocrMonochromeLow) base.ocrMonochromeHigh = base.ocrMonochromeLow;
      if (!base.saveFilenamePattern) base.saveFilenamePattern = "Screenshot_{yyyyMMdd_HHmmss}";
      d.screenshotConfig = base;
      return d;
    }
    function syncThemeAndPopupFromDom() {
      try {
        const tm = document.getElementById("themeMode");
        if (tm) state.data.themeMode = tm.value;
        const ps = document.getElementById("popupScreenIndex");
        if (ps) state.data.popupScreenIndex = Number(ps.value);
      } catch (_) {}
    }
    function readFromUI() {
      syncActivationModeFromDom();
      syncThemeAndPopupFromDom();
      let d = { ...state.data, voiceSearchEnabledCategories: [...state.data.voiceSearchEnabledCategories], floatingToolbarButtons: [...(state.data.floatingToolbarButtons||[])], floatingToolbarMenuItems: [...(state.data.floatingToolbarMenuItems||[])] };
      d = readGeneral(d); d = readAppearance(d); d = syncHoleDerivedFields(d); d = readPrompts(d); d = readHotkeys(d); d = readAdvanced(d); d = readScreenshot(d); d = readSearch(d); d = readCustomize(d);
      d.appearanceActivationMode = normalizeActivationMode(state.appearanceActivationMode);
      state.data.appearanceActivationMode = d.appearanceActivationMode;
      const dstEl = document.getElementById("defaultStartTab");
      if (!defaultStartTabDirty && !dstEl) delete d.defaultStartTab;
      return d;
    }
    function selectOpt(id, val){ const el = document.getElementById(id); if (el) el.value = val; }
    function options(items, selected){ return items.map(v => `<option value="${esc(v)}"${v===selected?" selected":""}>${esc(v)}</option>`).join(""); }
    function optionsKV(items, selected){ return items.map(it => `<option value="${esc(it.value)}"${it.value===selected?" selected":""}>${esc(it.label)}</option>`).join(""); }
    function normalizeActivationMode(v){
      const s = String(v || "").trim();
      if (s === "bubble") return "hole";
      return ACTIVATION_MODE_OPTIONS.some(o => o.value === s) ? s : "toolbar";
    }
    /** 从当前外观页单选项同步，避免仅点了选项未触发 state 更新时保存丢失 */
    function syncActivationModeFromDom() {
      try {
        const el = document.querySelector('input[name="activationMode"]:checked');
        if (el) state.appearanceActivationMode = normalizeActivationMode(el.value);
      } catch (_) {}
    }
    function loadAppearanceActivationMode(){
      try {
        const raw = localStorage.getItem(ACTIVATION_MODE_LOCAL_KEY);
        state.appearanceActivationMode = normalizeActivationMode(raw || state.appearanceActivationMode);
      } catch {
        state.appearanceActivationMode = normalizeActivationMode(state.appearanceActivationMode);
      }
    }
    function saveAppearanceActivationMode(){
      try {
        localStorage.setItem(ACTIVATION_MODE_LOCAL_KEY, normalizeActivationMode(state.appearanceActivationMode));
      } catch {}
    }
    function activationModeCardIconHtml(opt) {
      const kind = String(opt.iconKind || opt.value || "toolbar");
      const tone = `activation-mode-icon-${kind}`;
      if (kind === "hole") {
        return `<div class="activation-mode-icon ${tone}" aria-hidden="true"><div class="hole-ring-mini"></div></div>`;
      }
      if (kind === "tray") {
        return `<div class="activation-mode-icon ${tone}" aria-hidden="true"><img src="${esc(NIUMA_ICON_URL)}" alt=""><i class="fa-solid fa-tray-arrow-up"></i></div>`;
      }
      const ic = String(opt.iconClass || "fa-grip-lines").replace(/[^a-z0-9-]/gi, "");
      return `<div class="activation-mode-icon ${tone}" aria-hidden="true"><i class="fa-solid ${ic}"></i></div>`;
    }
    function activationModeOptionsHtml(selected){
      return ACTIVATION_MODE_OPTIONS.map((opt) => {
        const active = selected === opt.value;
        return `<label class="activation-mode-option ${active ? "active" : ""}" data-activation-item="${esc(opt.value)}">
  <input class="activation-mode-radio" type="radio" name="activationMode" value="${esc(opt.value)}" ${active ? "checked" : ""}>
  ${activationModeCardIconHtml(opt)}
  <div class="activation-mode-body">
    <div class="activation-mode-title">${esc(opt.label)}</div>
    <div class="activation-mode-desc">${esc(opt.desc)}</div>
  </div>
</label>`;
      }).join("");
    }
    function activationModePreviewHtml(mode){
      const m = normalizeActivationMode(mode);
      if (m === "hole") {
        return `<div class="mode-preview-scene">
  <div class="mode-hole-ring"><img src="${esc(NIUMA_ICON_URL)}" alt="黑洞模式"></div>
  <div class="hint">黑洞模式与悬浮栏互斥，桌面仅保留黑洞交互入口。</div>
</div>`;
      }
      if (m === "tray") {
        return `<div class="mode-preview-scene">
  <div class="mode-tray-mock"><img src="${esc(NIUMA_ICON_URL)}" alt="牛马图标"><i class="fa-solid fa-tray-arrow-up" style="opacity:.7;"></i><span>CursorHelper（托盘运行中）</span></div>
  <div class="hint">不显示悬浮 UI，仅托盘可见。</div>
</div>`;
      }
      return `<div class="mode-preview-scene">
  <div class="mode-toolbar-mock">
    <div class="mode-icon-bubble" style="width:28px;height:28px;border-radius:8px;box-shadow:none;"><img src="${esc(NIUMA_ICON_URL)}" alt="牛马图标" style="width:18px;height:18px;"></div>
    <span class="dot"><i class="fa-solid fa-magnifying-glass"></i></span>
    <span class="dot"><i class="fa-solid fa-clipboard"></i></span>
    <span class="dot"><i class="fa-solid fa-note-sticky"></i></span>
    <span class="dot"><i class="fa-solid fa-gear"></i></span>
  </div>
  <div class="hint">显示完整悬浮栏，图标和功能入口始终在桌面层。</div>
</div>`;
    }
    function bindAppearanceActivationMode(){
      document.querySelectorAll('input[name="activationMode"]').forEach((el) => {
        el.addEventListener("change", (e) => {
          e.stopPropagation();
          state.appearanceActivationMode = normalizeActivationMode(el.value);
          state.data.appearanceActivationMode = state.appearanceActivationMode;
          saveAppearanceActivationMode();
          if (activationModeSaveTimer) clearTimeout(activationModeSaveTimer);
          activationModeSaveTimer = 0;
          post({ type: "saveAppearanceActivationMode", mode: state.appearanceActivationMode });
          const prev = document.getElementById("activationModePreview");
          if (prev)
            prev.innerHTML = activationModePreviewHtml(state.appearanceActivationMode);
          document.querySelectorAll("[data-activation-item]").forEach((card) => {
            card.classList.toggle("active", card.getAttribute("data-activation-item") === state.appearanceActivationMode);
          });
          setStatus("激活方式已切换为：" + (ACTIVATION_MODE_OPTIONS.find(o => o.value === state.appearanceActivationMode)?.label || "悬浮栏"), "ok");
        });
      });
    }
    function applyWebTheme(mode){
      const root = document.documentElement;
      if (mode === "light") {
        root.style.setProperty("--bg", "#F7F7F7");
        root.style.setProperty("--app-bg", "#F7F7F7");
        root.style.setProperty("--color-scheme", "light");
        root.style.setProperty("--surface", "#ffffff");
        root.style.setProperty("--surface2", "#ffffff");
        root.style.setProperty("--surface3", "#ffffff");
        root.style.setProperty("--border", "#E5E5E5");
        root.style.setProperty("--border2", "#E5E5E5");
        root.style.setProperty("--panel-border", "#E5E5E5");
        root.style.setProperty("--orange", "#E67E22");
        root.style.setProperty("--orange-dk", "#D35400");
        root.style.setProperty("--orange-lt", "#E67E22");
        root.style.setProperty("--text", "#555555");
        root.style.setProperty("--text-dim", "#555555");
        root.style.setProperty("--text-xs", "#777777");
        root.style.setProperty("--title-text", "#2D2D2D");
        root.style.setProperty("--on-accent", "#FFFFFF");
        root.style.setProperty("--btn-hover-bg", "#FFF3E8");
        root.style.setProperty("--tab-hover-bg", "#FFF7EF");
        root.style.setProperty("--tab-hover-border", "#E9B889");
        root.style.setProperty("--tab-active-bg", "#FFF1E3");
        root.style.setProperty("--tab-active-border", "#E9B889");
        root.style.setProperty("--tab-active-text", "#D35400");
        root.style.setProperty("--subtab-active-bg", "#FFF1E3");
        root.style.setProperty("--subtab-active-border", "#E9B889");
        root.style.setProperty("--subtab-active-text", "#D35400");
        root.style.setProperty("--preview-bg", "#FFFFFF");
        root.style.setProperty("--preview-hint-text", "#555555");
        root.style.setProperty("--glass-edge", "rgba(0,0,0,.06)");
        root.style.setProperty("--glass-edge-soft", "rgba(0,0,0,.02)");
        root.style.setProperty("--glass-warm", "rgba(230,126,34,.12)");
        root.style.setProperty("--row-hover", "#F7F7F7");
        root.style.setProperty("--row-active", "#FFF4EA");
        root.style.setProperty("--row-active-text", "#2D2D2D");
        root.style.setProperty("--glow", "0 6px 16px rgba(0,0,0,.06)");
        root.style.setProperty("--glow-hot", "0 0 0 1px rgba(230,126,34,.16), 0 8px 20px rgba(211,84,0,.12)");
      } else {
        root.style.setProperty("--bg", "#0d1016");
        root.style.setProperty("--app-bg", "radial-gradient(circle at top right, rgba(58,107,168,.22), transparent 34%), linear-gradient(180deg, #0c1017 0%, #16253b 100%)");
        root.style.setProperty("--color-scheme", "dark");
        root.style.setProperty("--surface", "#132033");
        root.style.setProperty("--surface2", "#18293f");
        root.style.setProperty("--surface3", "#22354f");
        root.style.setProperty("--border", "#2b405c");
        root.style.setProperty("--border2", "#35506f");
        root.style.setProperty("--panel-border", "rgba(255,255,255,.12)");
        root.style.setProperty("--orange", "#ff8d2a");
        root.style.setProperty("--orange-dk", "#ff7a14");
        root.style.setProperty("--orange-lt", "#ffb347");
        root.style.setProperty("--text", "#e8e8e8");
        root.style.setProperty("--text-dim", "#9db0c6");
        root.style.setProperty("--text-xs", "#8194ab");
        root.style.setProperty("--title-text", "#ffffff");
        root.style.setProperty("--on-accent", "#ffffff");
        root.style.setProperty("--btn-hover-bg", "linear-gradient(180deg, rgba(255,179,71,.12), rgba(255,141,42,.08))");
        root.style.setProperty("--tab-hover-bg", "linear-gradient(180deg, rgba(255,179,71,.1), rgba(255,141,42,.08))");
        root.style.setProperty("--tab-hover-border", "rgba(255,179,71,.5)");
        root.style.setProperty("--tab-active-bg", "linear-gradient(180deg, rgba(255,179,71,.16), rgba(255,141,42,.12))");
        root.style.setProperty("--tab-active-border", "rgba(255,179,71,.5)");
        root.style.setProperty("--tab-active-text", "#ffffff");
        root.style.setProperty("--subtab-active-bg", "linear-gradient(180deg, rgba(255,179,71,.16), rgba(255,141,42,.12))");
        root.style.setProperty("--subtab-active-border", "rgba(255,179,71,.5)");
        root.style.setProperty("--subtab-active-text", "#ffffff");
        root.style.setProperty("--preview-bg", "var(--surface2)");
        root.style.setProperty("--preview-hint-text", "var(--text-dim)");
        root.style.setProperty("--glass-edge", "rgba(255,255,255,.28)");
        root.style.setProperty("--glass-edge-soft", "rgba(255,255,255,.08)");
        root.style.setProperty("--glass-warm", "rgba(255,171,92,.2)");
        root.style.setProperty("--row-hover", "#1f1f1f");
        root.style.setProperty("--row-active", "#2a1b0d");
        root.style.setProperty("--row-active-text", "#f0f0f0");
        root.style.setProperty("--glow", "0 18px 42px rgba(0,0,0,.35)");
        root.style.setProperty("--glow-hot", "0 0 0 1px rgba(255,179,71,.24), 0 14px 34px rgba(0,0,0,.28)");
      }
    }
    function normalizeAppUpdate(raw) {
      const u = raw && typeof raw === "object" ? raw : {};
      return {
        currentVersion: String(u.currentVersion || ""),
        latestVersion: String(u.latestVersion || ""),
        hasUpdate: !!u.hasUpdate,
        releaseUrl: String(u.releaseUrl || u.releasesPage || ""),
        releasesPage: String(u.releasesPage || "https://github.com/psterman/nmer/releases")
      };
    }
    function applyAppUpdateUi() {
      const u = normalizeAppUpdate(state.appUpdate);
      const pill = document.getElementById("appUpdatePill");
      const pillText = document.getElementById("appUpdatePillText");
      const headerDot = document.getElementById("headerUpdateDot");
      if (pill) pill.classList.toggle("visible", u.hasUpdate);
      if (pillText) pillText.textContent = u.hasUpdate ? (u.latestVersion ? `新版本 ${u.latestVersion}` : "有新版本") : "有新版本";
      if (headerDot) headerDot.style.display = u.hasUpdate ? "inline-block" : "none";
    }
    function renderAppUpdateGeneralBlock(u) {
      const cur = esc(u.currentVersion || "—");
      const latest = esc(u.latestVersion || "—");
      const banner = u.hasUpdate
        ? `<div class="app-update-banner visible"><div><strong>发现新版本</strong>：${latest}（当前 ${cur}）</div><button type="button" class="btn primary" id="btnOpenAppRelease">前往 GitHub 下载</button></div>`
        : "";
      const checkBtn = `<button type="button" class="btn" id="btnCheckAppUpdate">检查更新</button>`;
      return `${banner}<div class="row"><div class="label">软件版本</div><div class="inline"><span class="hint">${cur}</span>${checkBtn}</div></div>`;
    }
    function bindAppUpdateGeneralHandlers() {
      document.getElementById("btnOpenAppRelease")?.addEventListener("click", () => post({ type: "openAppRelease" }));
      document.getElementById("btnCheckAppUpdate")?.addEventListener("click", () => {
        setStatus("正在检查更新…", "");
        post({ type: "checkAppUpdate" });
      });
    }
    function requestCacheInfo() {
      post({ type: "cacheInfoRequest" });
    }
    function requestHealthSnapshot(trigger) {
      state.healthSnapshotLoading = true;
      renderHealthSnapshotDom(null, true);
      post({ type: "invokeAction", op: "getHealthSnapshot", payload: { trigger: trigger || "open_panel" } });
    }
    function renderHealthSnapshotDom(payload, loading) {
      const body = document.getElementById("healthSnapBody");
      const meta = document.getElementById("healthSnapMeta");
      if (!body) return;
      if (loading || state.healthSnapshotLoading) {
        if (meta) meta.textContent = "正在拉取只读快照…";
        body.innerHTML = `<div class="hint">正在观测侧车与 Surface 登记状态（不会自动修复）…</div>`;
        return;
      }
      const snap = payload || state.healthSnapshot;
      if (!snap || typeof snap !== "object") {
        if (meta) meta.textContent = "只读快照";
        body.innerHTML = `<div class="hint">暂无快照，请点击「刷新快照」。</div>`;
        return;
      }
      if (meta) {
        const t = String(snap.generatedAt || "").trim();
        const tr = String(snap.trigger || "").trim();
        meta.textContent = t ? `${t} · ${tr} · 只读` : "只读快照";
      }
      const services = Array.isArray(snap.services) ? snap.services : [];
      const surfaces = Array.isArray(snap.surfaces) ? snap.surfaces : [];
      const summary = (snap.summary && snap.summary.label) ? String(snap.summary.label) : "";
      const svcRows = services.length ? services.map(s => {
        const label = esc(String(s.label || s.name || ""));
        const proc = !!s.processPresent;
        const ok = !!s.healthy;
        const badge = ok ? `<span class="health-badge ok">健康</span>` : (proc ? `<span class="health-badge warn">异常</span>` : `<span class="health-badge err">未运行</span>`);
        return `<tr><td>${label}</td><td>${proc ? "是" : "否"}</td><td>${badge}</td></tr>`;
      }).join("") : `<tr><td colspan="3" class="hint">无侧车登记</td></tr>`;
      const surfRows = surfaces.length ? surfaces.map(s =>
        `<tr><td>${esc(String(s.id || ""))}</td><td>${esc(String(s.state || ""))}</td><td>${esc(String(s.role || ""))}</td></tr>`
      ).join("") : `<tr><td colspan="3" class="hint">无 Surface 登记文件（观测未启用或尚无快照）</td></tr>`;
      const dbgDir = esc(String((snap.logs && snap.logs.debugDir) || ""));
      body.innerHTML = `
        <div class="hint health-snap-note">${summary ? esc(summary) + " · " : ""}本页仅展示状态，不会自动修复或拉起进程</div>
        <div class="health-section-title">侧车</div>
        <table class="health-table"><thead><tr><th>服务</th><th>进程</th><th>状态</th></tr></thead><tbody>${svcRows}</tbody></table>
        <div class="health-section-title">Surface 登记</div>
        <table class="health-table"><thead><tr><th>ID</th><th>状态</th><th>角色</th></tr></thead><tbody>${surfRows}</tbody></table>
        ${dbgDir ? `<div class="hint health-log-dir">日志目录：${dbgDir}</div>` : ""}`;
    }
    function renderTroubleshootCardHtml() {
      return `<div class="card" style="margin-top:12px;">
  <div class="title">故障排查</div>
  <div class="hint" style="margin-bottom:10px;">出问题时<strong>不必手改 ini</strong>。日志在 <code>Cache\\debug\\nmer_trace.log</code>；也可用下面按钮一键收集信息。</div>
  <ul class="hint" style="margin:0 0 10px 18px;line-height:1.55;">
    <li>牛马无反应 → 托盘右键「系统健康」或下方「健康快照」</li>
    <li>快捷键冲突 → 「快捷键冲突」跳到快捷键页</li>
    <li>要发给开发者 → 「复制最近日志」或「导出诊断包」</li>
    <li>恢复默认（不含 API Key）→ 「恢复默认设置」</li>
  </ul>
  <div class="inline" style="flex-wrap:wrap;gap:8px;">
    <button type="button" class="btn" id="btnTroubleOpenLogs">打开日志目录</button>
    <button type="button" class="btn" id="btnTroubleCopyTrace">复制最近日志</button>
    <button type="button" class="btn" id="btnTroubleExportDiag">导出诊断包</button>
    <button type="button" class="btn" id="btnTroubleHealth">健康快照</button>
    <button type="button" class="btn" id="btnTroubleHotkeys">快捷键冲突</button>
    <button type="button" class="btn" id="btnTroubleResetCfg">恢复默认设置</button>
  </div>
</div>`;
    }
    function bindTroubleshootHandlers() {
      document.getElementById("btnTroubleOpenLogs")?.addEventListener("click", () => post({ type: "invokeAction", op: "openDebugLogsFolder" }));
      document.getElementById("btnTroubleCopyTrace")?.addEventListener("click", () => {
        setStatus("正在复制最近日志…", "");
        post({ type: "invokeAction", op: "copyRecentTraceLog" });
      });
      document.getElementById("btnTroubleExportDiag")?.addEventListener("click", () => post({ type: "invokeAction", op: "exportDiagnosticsBundle" }));
      document.getElementById("btnTroubleHealth")?.addEventListener("click", () => {
        state.activeTab = "advanced";
        try { sessionStorage.setItem("settings.activeTab", "advanced"); } catch (_) {}
        document.querySelectorAll(".tab-btn").forEach(b => b.classList.toggle("active", b.dataset.tab === "advanced"));
        render();
        requestHealthSnapshot("troubleshoot_guide");
        setStatus("已打开「高级 → 系统健康」", "ok");
      });
      document.getElementById("btnTroubleHotkeys")?.addEventListener("click", () => {
        state.activeTab = "hotkeys";
        state.hotkeysSubTab = "overview";
        try { sessionStorage.setItem("settings.activeTab", "hotkeys"); } catch (_) {}
        document.querySelectorAll(".tab-btn").forEach(b => b.classList.toggle("active", b.dataset.tab === "hotkeys"));
        render();
        setStatus("已跳到「快捷键」页，可检查 CapsLock 和弦层", "ok");
      });
      document.getElementById("btnTroubleResetCfg")?.addEventListener("click", async () => {
        const ask = window.nmConfirm
          ? await window.nmConfirm("恢复默认设置", "将重置 CursorShortcut.ini 为默认值（API Key 在 vault 中，不受影响）。是否继续？", { okLabel: "恢复", cancelLabel: "取消", danger: true })
          : confirm("恢复默认设置？API Key 不受影响。");
        if (ask) post({ type: "invokeAction", op: "resetToDefaults" });
      });
    }
    function bindHealthSnapshotHandlers() {
      document.getElementById("btnHealthRefresh")?.addEventListener("click", () => requestHealthSnapshot("user_refresh"));
      document.getElementById("btnHealthExportDiag")?.addEventListener("click", () => post({ type: "invokeAction", op: "exportDiagnosticsBundle" }));
      document.getElementById("btnHealthOpenLogs")?.addEventListener("click", () => post({ type: "invokeAction", op: "openDebugLogsFolder" }));
    }
    function collectCacheClearTargets() {
      return Array.from(document.querySelectorAll(".cache-clear-chk:checked")).map(el => el.dataset.cacheId).filter(Boolean);
    }
    const MIGRATION_CATEGORY_LABELS = { local: "本地配置", data: "持久数据", cache: "缓存（可选）" };
    function requestMigrationOptions() {
      post({ type: "invokeAction", op: "getMigrationOptions" });
    }
    function migrationPresetGroups(presetId) {
      const presets = state.migrationOptions?.presets;
      if (!Array.isArray(presets)) return null;
      const p = presets.find(x => x.id === presetId);
      return p && Array.isArray(p.groups) ? p.groups.slice() : null;
    }
    function migrationDefaultSelectedGroups() {
      const fromPreset = migrationPresetGroups(state.migrationPreset || "recommended");
      if (fromPreset && fromPreset.length) return fromPreset;
      const groups = state.migrationOptions?.groups;
      if (!Array.isArray(groups)) return [];
      return groups.filter(g => g.default).map(g => g.id);
    }
    function migrationCurrentSelectedGroups() {
      if (Array.isArray(state.migrationSelectedGroups) && state.migrationSelectedGroups.length)
        return state.migrationSelectedGroups.slice();
      return migrationDefaultSelectedGroups();
    }
    function migrationGroupMeta(id) {
      const groups = state.migrationOptions?.groups;
      if (!Array.isArray(groups)) return null;
      return groups.find(g => g.id === id) || null;
    }
    function migrationSelectedSizeText(selectedIds) {
      let bytes = 0;
      for (const id of selectedIds) {
        const g = migrationGroupMeta(id);
        if (g) bytes += Number(g.bytes || 0);
      }
      return formatBytes(bytes);
    }
    function formatBytes(n) {
      n = Number(n || 0);
      if (n < 1024) return `${Math.round(n)} B`;
      if (n < 1048576) return `${(n / 1024).toFixed(1)} KB`;
      if (n < 1073741824) return `${(n / 1048576).toFixed(2)} MB`;
      return `${(n / 1073741824).toFixed(2)} GB`;
    }
    function renderMigrationGroupRows(selectedIds) {
      const groups = Array.isArray(state.migrationOptions?.groups) ? state.migrationOptions.groups : [];
      const byCat = { local: [], data: [], cache: [] };
      for (const g of groups) {
        const cat = byCat[g.category] ? g.category : "data";
        if (!byCat[cat]) byCat[cat] = [];
        byCat[cat].push(g);
      }
      const order = ["local", "data", "cache"];
      return order.map(cat => {
        const items = byCat[cat];
        if (!items.length) return "";
        const rows = items.map(g => {
          const checked = selectedIds.includes(g.id);
          const disabled = state.migrationPreset !== "custom" ? "disabled" : "";
          const existsHint = g.exists ? "" : " <span class=\"hint\">（本机暂无）</span>";
          return `<label class="tag migration-group-row" style="display:flex;align-items:flex-start;gap:8px;margin:6px 0;">
            <input type="checkbox" class="migration-group-chk" data-migration-group="${esc(g.id)}" data-nosave="1" ${checked ? "checked" : ""} ${disabled}>
            <span><strong>${esc(g.label)}</strong>${existsHint}<div class="hint">${esc(g.hint || "")} · ${esc(g.sizeText || "0 B")}</div></span>
          </label>`;
        }).join("");
        return `<div class="migration-cat" style="margin-top:10px;"><div class="hint" style="font-weight:600;margin-bottom:4px;">${esc(MIGRATION_CATEGORY_LABELS[cat] || cat)}</div>${rows}</div>`;
      }).join("");
    }
    function updateMigrationSelectedSummary() {
      const el = document.getElementById("migrationSelectedSummary");
      if (!el) return;
      const sel = migrationCurrentSelectedGroups();
      el.textContent = sel.length ? `已选 ${sel.length} 项，约 ${migrationSelectedSizeText(sel)}` : "请至少选择一项";
    }
    function applyMigrationPresetToDom(presetId) {
      state.migrationPreset = presetId;
      if (presetId !== "custom") {
        state.migrationSelectedGroups = migrationPresetGroups(presetId) || migrationDefaultSelectedGroups();
      }
      const sel = document.getElementById("migrationPreset");
      if (sel) sel.value = presetId;
      document.querySelectorAll(".migration-group-chk").forEach(chk => {
        const gid = chk.dataset.migrationGroup;
        const on = migrationCurrentSelectedGroups().includes(gid);
        chk.checked = on;
        chk.disabled = presetId !== "custom";
      });
      updateMigrationSelectedSummary();
    }
    function collectMigrationExportPayload() {
      const preset = String(document.getElementById("migrationPreset")?.value || state.migrationPreset || "recommended");
      if (preset === "custom") {
        const groups = Array.from(document.querySelectorAll(".migration-group-chk:checked")).map(el => el.dataset.migrationGroup).filter(Boolean);
        return { preset: "custom", groups };
      }
      return { preset };
    }
    function bindMigrationHandlers() {
      document.getElementById("migrationPreset")?.addEventListener("change", (e) => {
        applyMigrationPresetToDom(String(e.target.value || "recommended"));
      });
      document.querySelectorAll(".migration-group-chk").forEach(chk => {
        chk.addEventListener("change", () => {
          state.migrationPreset = "custom";
          state.migrationSelectedGroups = Array.from(document.querySelectorAll(".migration-group-chk:checked")).map(el => el.dataset.migrationGroup).filter(Boolean);
          const sel = document.getElementById("migrationPreset");
          if (sel) sel.value = "custom";
          document.querySelectorAll(".migration-group-chk").forEach(c => { c.disabled = false; });
          updateMigrationSelectedSummary();
        });
      });
      document.getElementById("btnMigrationRefresh")?.addEventListener("click", () => {
        setStatus("正在刷新迁移项统计…", "");
        requestMigrationOptions();
      });
      document.getElementById("btnMigrationExport")?.addEventListener("click", () => {
        const payload = collectMigrationExportPayload();
        const sel = payload.groups || migrationPresetGroups(payload.preset) || migrationDefaultSelectedGroups();
        if (!sel.length) return setStatus("请至少选择一项迁移内容", "err");
        setStatus("正在导出迁移包…", "");
        post({ type: "invokeAction", op: "exportMigrationPack", payload });
      });
      document.getElementById("btnMigrationImport")?.addEventListener("click", () => {
        setStatus("请选择迁移包 zip…", "");
        post({ type: "invokeAction", op: "importMigrationPack", payload: { confirmed: false } });
      });
    }
    async function confirmMigrationImport(preview) {
      const zipPath = String(preview?.zipPath || "").trim();
      if (!zipPath) return false;
      const groups = Array.isArray(preview.groups) ? preview.groups : [];
      const groupLines = groups.length
        ? groups.map(g => {
            const meta = migrationGroupMeta(g.id);
            const label = meta?.label || g.label || g.id;
            return `· ${label}${g.fileCount ? `（${g.fileCount} 项）` : ""}`;
          }).join("\n")
        : `· 共 ${Number(preview.fileCount || 0)} 个文件`;
      const body = [
        `将用迁移包覆盖本机对应数据（先备份到 local/backup-migration-*）。`,
        ``,
        `包内分组：`,
        groupLines,
        ``,
        `导入后需重新填写 API Key，建议完成后重启牛马。`
      ].join("\n");
      return window.nmConfirm
        ? window.nmConfirm("导入迁移包？", body, { okLabel: "确认导入", cancelLabel: "取消", danger: true })
        : Promise.resolve(confirm(body));
    }
    function bindStorageCacheHandlers() {
      document.getElementById("btnCacheRefresh")?.addEventListener("click", () => {
        setStatus("正在统计缓存…", "");
        requestCacheInfo();
      });
      document.getElementById("btnCacheOpenRoot")?.addEventListener("click", () => post({ type: "cacheOpenFolder", target: "root" }));
      document.querySelectorAll(".cache-open-btn").forEach(btn => btn.addEventListener("click", () => post({ type: "cacheOpenFolder", target: btn.dataset.cacheTarget || "root" })));
      document.getElementById("btnCachePickRoot")?.addEventListener("click", () => post({ type: "cachePickRoot" }));
      document.getElementById("btnCacheClearSelected")?.addEventListener("click", async () => {
        const targets = collectCacheClearTargets();
        if (!targets.length) return setStatus("请至少选择一项要清空的缓存", "err");
        const ok = await (window.nmConfirm ? window.nmConfirm(
          "清空所选缓存？",
          "确定清空所选缓存？全文索引清空后将自动触发重建；图片清空可能导致历史剪贴板图片无法显示。",
          { okLabel: "清空", cancelLabel: "取消", danger: true }
        ) : Promise.resolve(confirm("确定清空所选缓存？全文索引清空后将自动触发重建；图片清空可能导致历史剪贴板图片无法显示。")));
        if (!ok) return;
        setStatus("正在清空缓存…", "");
        post({ type: "cacheClear", targets });
      });
      document.getElementById("btnCacheClearAll")?.addEventListener("click", async () => {
        const ok = await (window.nmConfirm ? window.nmConfirm(
          "清空全部缓存？",
          "确定清空全部缓存（含全文索引、图片、缩略图、临时文件、调试日志）？数据库记录不会删除，但部分图片/全文结果可能不可用。",
          { okLabel: "清空全部", cancelLabel: "取消", danger: true }
        ) : Promise.resolve(confirm("确定清空全部缓存（含全文索引、图片、缩略图、临时文件、调试日志）？数据库记录不会删除，但部分图片/全文结果可能不可用。")));
        if (!ok) return;
        setStatus("正在清空全部缓存…", "");
        post({ type: "cacheClear", targets: ["fulltext", "images", "thumbs", "temp", "debug"] });
      });
    }
    function render() {
      trace("render_begin", "", { tab: state.activeTab });
      destroyFtbWorkbenchSortable();
      destroyMenuWorkbenchSortable();
      const d = state.data; const panel = document.getElementById("panel");
      applyWebTheme(d.themeMode || "dark");
      const defaultTabOpts = [
        { value:"general", label:"通用设置" },
        { value:"appearance", label:"外观设置" },
        { value:"prompts", label:"提示词设置" },
        { value:"hotkeys", label:"快捷键设置" },
        { value:"advanced", label:"高级设置" },
        { value:"storage", label:"存储与缓存" },
        { value:"screenshot", label:"截图设置" },
        { value:"search", label:"搜索设置" },
        { value:"customize", label:"智能定制" }
      ];
      const monitorCount = Math.max(1, Number(d.monitorCount || 1));
      const screenOpts = Array.from({ length: monitorCount }, (_, i) => ({ value: String(i + 1), label: `显示器${i + 1}` }));
      const withCurrentOption = (opts, cur) => {
        const curStr = String(cur ?? "");
        if (opts.some(o => String(o.value) === curStr))
          return opts;
        return [{ value: curStr, label: `当前值（${curStr}）` }, ...opts];
      };
      const cursorList = (Array.isArray(d.cursorShortcuts) && d.cursorShortcuts.length) ? d.cursorShortcuts : DEFAULT_CURSOR_SHORTCUTS;
      const cursorShortcutRows = renderCursorShortcutRefRows(cursorList);
      const appShortcutRows = renderAppShortcutRefRows();
      const capsHold = Number(d.capslockHoldTimeSeconds);
      const capsHoldHint = Number.isFinite(capsHold) ? capsHold.toFixed(1) : "0.5";
      const catRows = ALL_CATEGORIES.map(c => `<label class="tag"><input id="cat_${c}" type="checkbox" ${checked((d.voiceSearchEnabledCategories||[]).includes(c))}> ${esc(c)}</label>`).join("");
      if (state.activeTab === "general") {
        const upd = normalizeAppUpdate(state.appUpdate);
        panel.innerHTML = `<div class="card"><div class="title">通用设置</div>${renderAppUpdateGeneralBlock(upd)}<div class="row"><div class="label">Cursor 路径</div><div class="inline"><input id="cursorPath" type="text" value="${esc(d.cursorPath)}"><button class="btn" id="browsePath">浏览</button></div></div><div class="row"><div class="label">CapsLock 长按时间 (0.1 - 5.0)</div><input id="holdTime" type="number" min="0.1" max="5.0" step="0.1" value="${esc(d.capslockHoldTimeSeconds)}"></div><div class="row"><div class="label">开机自启动</div><div><input id="autoStart" type="checkbox" ${checked(d.autoStart)}></div></div><div class="row"><div class="label">默认启动页</div><select id="defaultStartTab">${optionsKV(defaultTabOpts, normalizeDefaultStartTab(d.defaultStartTab))}</select></div></div>${renderTroubleshootCardHtml()}`;
        bindAppUpdateGeneralHandlers();
        bindTroubleshootHandlers();
        document.getElementById("browsePath").addEventListener("click", () => post({ type: "browseCursorPath" }));
      } else if (state.activeTab === "appearance") {
        const activationMode = normalizeActivationMode(state.appearanceActivationMode);
        panel.innerHTML = `<div class="card activation-mode-card">
  <div class="title">激活方式</div>
  <div class="hint">选择悬浮栏、黑洞模式或仅托盘；修改后将写入配置并立即生效。</div>
  <div class="activation-mode-group">${activationModeOptionsHtml(activationMode)}</div>
  <div class="activation-mode-preview">
    <div class="mode-preview-title">模式预览</div>
    <div id="activationModePreview">${activationModePreviewHtml(activationMode)}</div>
  </div>
</div>
<div class="card"><div class="title">外观设置</div><div class="row"><div class="label">主题模式</div><select id="themeMode">${optionsKV([{value:"dark",label:"深色"},{value:"light",label:"浅色"}],d.themeMode)}</select></div><div class="row"><div class="label">弹窗位置</div><select id="popupScreenIndex">${optionsKV(screenOpts, String(d.popupScreenIndex || 1))}</select></div><div class="hint">已自动识别显示器数量：${esc(monitorCount)}。此设置会应用到所有弹窗并固定保存。</div></div>
<div class="card"><div class="title">黑洞</div>
<div class="hint">仅当激活方式为<strong>黑洞模式</strong>时生效；下方修改会自动保存。</div>
<div class="hole-preview-wrap">
  <div class="mode-preview-title">外观预览</div>
  <div class="hole-preview-stage" id="holeStylePreview"></div>
  <div class="hole-preview-meta" id="holePreviewMeta"></div>
  <div class="inline" style="margin-top:10px;justify-content:center;"><button type="button" class="btn" id="btnPreviewHoleOnScreen">在屏幕上预览 3 秒</button></div>
</div>
<input type="hidden" id="holePositionMode" value="${esc(d.holePositionMode || "anchor")}">
<input type="hidden" id="holeVisualStyle" value="${esc(d.holeVisualStyle || "ring")}">
<input type="hidden" id="holeAnimLevel" value="${esc(d.holeAnimLevel ?? 1.0)}">
<input type="hidden" id="holeHideDockEnabled" value="${d.holeHideDockEnabled !== false ? "1" : "0"}">
<input type="hidden" id="holeHideDockMargin" value="${esc(d.holeHideDockMargin ?? 10)}">
<div class="row"><div class="label">样式</div><div class="hole-style-chips" id="holeStyleChips">
<button type="button" class="hole-chip ${(d.holeVisualStyle || "ring") === "ring" ? "active" : ""}" data-hole-style="ring">彩环</button>
<button type="button" class="hole-chip ${d.holeVisualStyle === "starry" ? "active" : ""}" data-hole-style="starry">星空</button>
</div></div>
<div class="row"><div class="label">大小</div><div class="hole-size-row"><input id="holeSizeScale" type="range" min="0.85" max="1.5" step="0.05" value="${esc(Number(d.holeSizeScale ?? 1) || 1)}"><span class="hole-size-label" id="holeSizeScaleLabel">标准</span></div></div>
<div class="row"><div class="label">接近范围</div><select id="holeSensitivityPreset">${optionsKV([{value:"compact",label:"紧凑（更易收起）"},{value:"standard",label:"标准"},{value:"relaxed",label:"宽松（更易保持）"}], String(d.holeSensitivityPreset || "standard"))}</select></div>
<div class="row"><div class="label">出现位置</div><select id="holePlacementPreset">${optionsKV([{value:"cursor",label:"跟随选区 / 光标"},{value:"fixed",label:"屏幕固定坐标"},{value:"edge",label:"隐藏时贴屏幕边缘"}], String(d.holePlacementPreset || "cursor"))}</select></div>
<div class="row hole-fixed-row" id="holeFixedRow"><div class="label">固定坐标 X / Y</div><div class="inline"><input id="holeFixedX" type="number" step="1" value="${esc(d.holeFixedX ?? 360)}"><input id="holeFixedY" type="number" step="1" value="${esc(d.holeFixedY ?? 260)}"></div></div>
<div class="row hole-edge-row" id="holeEdgeRow"><div class="label">贴边方向</div><select id="holeHideDockEdge">${optionsKV([{value:"right",label:"右侧"},{value:"left",label:"左侧"},{value:"top",label:"顶部"},{value:"bottom",label:"底部"}], String(d.holeHideDockEdge || "right"))}</select></div>
<div class="title" style="margin-top:6px;font-size:13px;">唤起方式</div>
<div class="hole-trigger-grid">
<label class="hole-trigger-item"><input id="holeTriggerTextSelect" type="checkbox" ${checked(!!d.holeTriggerTextSelect)}>选中文本</label>
<label class="hole-trigger-item"><input id="holeTriggerCircleCw" type="checkbox" ${checked(!!d.holeTriggerCircleCw)}>画圈（顺时针）</label>
<label class="hole-trigger-item"><input id="holeTriggerCircleCcw" type="checkbox" ${checked(!!d.holeTriggerCircleCcw)}>画圈（逆时针）</label>
<label class="hole-trigger-item"><input id="holeTriggerRButtonHold" type="checkbox" ${checked(!!d.holeTriggerRButtonHold)}>长按右键</label>
</div>
<div class="row hole-rbtn-row" id="holeRbtnRow"><div class="label">长按右键时长</div><select id="holeRButtonHoldMs">${optionsKV(HOLE_RBUTTON_HOLD_MS_OPTS, String(normalizeHoleRButtonHoldMs(d.holeRButtonHoldMs ?? 3000)))}</select></div>
<div class="hint">画圈：按住<strong>右键</strong>拖动轨迹，识别成功（轨迹变绿）后<strong>松手</strong>唤起；未闭合或未识别时松手不会触发。长按右键：按住<strong>不动</strong>达到所选时长后唤起（到时会提前弹出，无需等松手）；移动超过约 20 像素则进入画圈模式。至少勾选一种唤起方式。</div>
</div>`;
        bindAppearanceActivationMode();
        bindHoleSettingsUi();
      } else if (state.activeTab === "prompts") {
        const fixedCategories = ["基础","专业","改错","优化","解释","重构"];
        const tplAll = d.promptTemplateSummary || [];
        const dynamicCats = Array.from(new Set(tplAll.map(t => (t.category || "").trim()).filter(Boolean)));
        const allCats = [...new Set([...fixedCategories, ...dynamicCats, ...(state.customPromptCategories || [])])];
        if (!allCats.includes(state.promptsCategoryTab))
          state.promptsCategoryTab = "基础";
        const keyword = (state.promptsSearchKeyword || "").trim().toLowerCase();
        const filteredByCategory = tplAll.filter(t => {
          const cat = (t.category || "基础").trim();
          const byCat = cat === state.promptsCategoryTab;
          if (!byCat) return false;
          return true;
        });
        const filteredByKeyword = tplAll.filter(t => {
          if (!keyword) return true;
          return [t.id, t.title, t.content, t.category].some(v => String(v || "").toLowerCase().includes(keyword));
        });
        const filteredRaw = keyword ? filteredByKeyword : filteredByCategory;
        const dedupeMap = new Map();
        for (const t of filteredRaw) {
          const key = String(t?.id || "").trim() || `${String(t?.title || "").trim()}::${String(t?.category || "").trim()}`;
          if (!dedupeMap.has(key))
            dedupeMap.set(key, t);
        }
        const filtered = Array.from(dedupeMap.values());
        if (state.selectedPromptTemplateId && !filtered.some(t => t.id === state.selectedPromptTemplateId))
          state.selectedPromptTemplateId = "";
        const selected = state.creatingPromptTemplate
          ? null
          : (filtered.find(t => t.id === state.selectedPromptTemplateId) || filtered[0] || null);
        const catTabs = allCats.map(c => `<button class="subtab-btn ${state.promptsCategoryTab === c ? "active" : ""}" data-prompt-cat="${esc(c)}">${esc(c)}</button>`).join("");
        const listRows = filtered.map(t => `<div class="list-row ${selected?.id === t.id ? "active" : ""}" data-prompt-id="${esc(t.id)}"><div>${esc(t.title || t.id)}</div><div>${esc((t.content || "").replace(/\s+/g, " ").slice(0, 96))}</div></div>`).join("");
        const presetOpts = (d.promptTemplates || []).map(p => `<option value="${esc(p.id)}">${esc(p.title || p.id)} (${esc(p.category || "基础")})</option>`).join("");
        panel.innerHTML = `<div class="card"><div class="subtabs"><button class="subtab-btn ${state.promptsMainTab === "templateManager" ? "active" : ""}" data-prompt-main="templateManager">模板管理</button><button class="subtab-btn ${state.promptsMainTab === "cursorRules" ? "active" : ""}" data-prompt-main="cursorRules">cursor规则</button></div>${state.promptsMainTab === "templateManager" ? `<div class="search-row"><div class="inline"><input id="promptSearchKeyword" data-nosave="1" type="text" placeholder="搜索模板关键词（自动匹配全部模板）" value="${esc(state.promptsSearchKeyword)}"><button class="btn" id="btnPromptSearchClear">清空</button></div></div><div class="subtabs">${catTabs}</div><div class="prompt-grid"><div class="list-panel"><div class="list-head"><div>名称</div><div>内容</div></div><div class="list-body">${listRows || `<div class="list-row"><div>-</div><div>未匹配到模板</div></div>`}</div></div><div><div class="compact-row"><div class="label">预设模板</div><select id="promptTemplatePreset" data-nosave="1"><option value="">选择预设填充…</option>${presetOpts}</select></div><div class="compact-row"><div class="label">模板标题</div><input id="promptTplTitle" type="text" value="${esc(selected?.title || "")}"></div><div class="compact-row"><div class="label">模板分类</div><div class="inline"><select id="promptTplCategory">${options(allCats, (selected?.category || state.promptsCategoryTab))}</select><button class="btn" id="btnAddCategory">新建分类</button><button class="btn" id="btnDeleteCategory">删除分类</button></div></div><div class="label">模板内容</div><div class="editor-toolbar"><button class="btn" data-editor-action="bold">加粗</button><button class="btn" data-editor-action="code">代码</button><button class="btn" data-editor-action="quote">引用</button><button class="btn" data-editor-action="ul">列表</button><button class="btn" data-editor-action="undo">撤销</button><button class="btn" data-editor-action="redo">重做</button><button class="btn" data-editor-action="clear">清空</button></div><textarea id="promptTplContent" style="min-height:260px;">${esc(selected?.content || "")}</textarea><div class="inline" style="margin-top:8px;"><button class="btn" id="btnTplNew">新建模板</button><button class="btn" id="btnTplSave">保存模板</button><button class="btn" id="btnTplDelete">删除模板</button></div><div class="inline" style="margin-top:8px;"><button class="btn" id="btnImportTpl">导入模板</button><button class="btn" id="btnExportTpl">导出模板</button><button class="btn" id="btnReloadTpl">重载模板</button></div></div></div>` : (() => { const ruleTabs = [{k:"general",n:"通用规则"},{k:"web",n:"网页开发"},{k:"miniprogram",n:"小程序"},{k:"android",n:"安卓App"},{k:"ios",n:"iOS App"},{k:"python",n:"Python"}]; const tabHtml = ruleTabs.map(t => `<button class="subtab-btn ${state.cursorRulesTab===t.k?"active":""}" data-rule-tab="${t.k}">${t.n}</button>`).join(""); const content = d.cursorRules?.[state.cursorRulesTab] || ""; return `<div class="title">Cursor规则配置</div><div class="hint">根据开发类型配置规则，让 AI 更精准理解项目上下文，减少无效对话与返工。</div><div class="title" style="margin-top:10px;">📋 复制位置</div><div class="hint">在 Cursor 中按 Ctrl+Shift+P 打开命令面板，输入 <code>rules</code> 或 <code>cursor rules</code>，选择 Open Cursor Rules，粘贴到 <code>.cursorrules</code> 文件。</div><div class="title" style="margin-top:10px;">💡 使用方法</div><div class="hint">1. 选择下方开发类型标签 2. 编辑或粘贴规则 3. 点击复制规则 4. 粘贴保存到 Cursor 规则文件 5. 重启 Cursor 生效。</div><div class="subtabs" style="margin-top:10px;">${tabHtml}</div><div class="label">规则内容</div><textarea id="cursorRuleContent" style="min-height:320px;">${esc(content)}</textarea><div class="inline" style="margin-top:8px;"><button class="btn" id="btnCursorRulesCopy">复制规则</button></div>`; })()}</div>`;
        document.querySelectorAll("[data-prompt-main]").forEach(el => el.addEventListener("click", () => { state.promptsMainTab = el.getAttribute("data-prompt-main"); render(); }));
        if (state.promptsMainTab === "templateManager") {
          const searchEl = document.getElementById("promptSearchKeyword");
          const renderWithSearchFocus = (val, cursorPos) => {
            state.promptsSearchKeyword = val || "";
            render();
            const next = document.getElementById("promptSearchKeyword");
            if (next) {
              next.focus();
              const p = Math.max(0, Math.min(Number(cursorPos ?? next.value.length), next.value.length));
              try { next.setSelectionRange(p, p); } catch {}
            }
          };
          searchEl.addEventListener("compositionstart", () => { state.promptsSearchComposing = true; });
          searchEl.addEventListener("compositionend", (e) => {
            state.promptsSearchComposing = false;
            renderWithSearchFocus(e.target.value || "", e.target.selectionStart ?? (e.target.value || "").length);
          });
          searchEl.addEventListener("input", (e) => {
            if (state.promptsSearchComposing) return;
            renderWithSearchFocus(e.target.value || "", e.target.selectionStart ?? (e.target.value || "").length);
          });
          searchEl.addEventListener("keydown", (e) => {
            if (e.key === "Enter") {
              renderWithSearchFocus(e.target.value || "", e.target.selectionStart ?? (e.target.value || "").length);
            }
          });
          document.getElementById("btnPromptSearchClear").addEventListener("click", () => {
            renderWithSearchFocus("", 0);
          });
          document.querySelectorAll("[data-prompt-cat]").forEach(el => el.addEventListener("click", () => { state.promptsCategoryTab = el.getAttribute("data-prompt-cat"); render(); }));
          document.querySelectorAll("[data-prompt-id]").forEach(el => el.addEventListener("click", () => { state.selectedPromptTemplateId = el.getAttribute("data-prompt-id"); state.creatingPromptTemplate = false; render(); }));
          const presetEl = document.getElementById("promptTemplatePreset");
          if (presetEl) presetEl.addEventListener("change", () => {
            const id = presetEl.value;
            if (!id) return;
            const preset = (d.promptTemplates || []).find(p => p.id === id);
            if (!preset) return;
            const titleEl = document.getElementById("promptTplTitle");
            const catEl = document.getElementById("promptTplCategory");
            const bodyEl = document.getElementById("promptTplContent");
            if (titleEl) titleEl.value = preset.title || preset.id || "";
            if (catEl && preset.category) catEl.value = preset.category;
            if (bodyEl) bodyEl.value = preset.body || preset.content || "";
            state.creatingPromptTemplate = true;
            state.selectedPromptTemplateId = "";
            presetEl.value = "";
            setStatus("已填充预设模板，可编辑后保存", "ok");
          });
          const contentEl = document.getElementById("promptTplContent");
          document.querySelectorAll("[data-editor-action]").forEach(btn => btn.addEventListener("click", () => {
            const action = btn.getAttribute("data-editor-action");
            const insertWrap = (left, right = "") => {
              const start = contentEl.selectionStart || 0;
              const end = contentEl.selectionEnd || 0;
              const cur = contentEl.value || "";
              const selectedText = cur.slice(start, end);
              contentEl.value = cur.slice(0, start) + left + selectedText + right + cur.slice(end);
              contentEl.focus();
              const pos = start + left.length + selectedText.length + right.length;
              contentEl.setSelectionRange(pos, pos);
            };
            if (action === "bold") insertWrap("**", "**");
            else if (action === "code") insertWrap("```text\n", "\n```");
            else if (action === "quote") insertWrap("> ");
            else if (action === "ul") insertWrap("- ");
            else if (action === "undo") document.execCommand("undo");
            else if (action === "redo") document.execCommand("redo");
            else if (action === "clear") contentEl.value = "";
          }));
          document.getElementById("btnAddCategory").addEventListener("click", async () => {
            const v = await (window.nmPrompt ? window.nmPrompt("请输入新分类名称", "") : Promise.resolve(prompt("请输入新分类名称")));
            if (!v) return;
            const val = v.trim();
            if (!val) return;
            if (!(state.customPromptCategories || []).includes(val))
              state.customPromptCategories = [...(state.customPromptCategories || []), val];
            saveCustomCategories();
            state.promptsCategoryTab = val;
            render();
          });
          document.getElementById("btnDeleteCategory").addEventListener("click", () => {
            const category = state.promptsCategoryTab;
            if (!category || fixedCategories.includes(category)) return setStatus("基础分类不可删除", "err");
            const inCat = tplAll.filter(t => (t.category || "").trim() === category);
            if (!inCat.length) {
              state.customPromptCategories = (state.customPromptCategories || []).filter(c => c !== category);
              saveCustomCategories();
              state.promptsCategoryTab = "基础";
              return render();
            }
            for (const item of inCat) {
              post({ type: "invokeAction", op: "promptTemplateUpsert", payload: { id: item.id, title: item.title || item.id, category: "基础", content: item.content || "" } });
            }
            state.customPromptCategories = (state.customPromptCategories || []).filter(c => c !== category);
            saveCustomCategories();
            state.promptsCategoryTab = "基础";
            setStatus("分类已清空并迁移到“基础”", "ok");
            render();
          });
          document.getElementById("btnTplNew").addEventListener("click", () => {
            state.selectedPromptTemplateId = "";
            state.creatingPromptTemplate = true;
            render();
          });
          document.getElementById("btnTplSave").addEventListener("click", () => {
            post({ type: "invokeAction", op: "promptTemplateUpsert", payload: { id: state.selectedPromptTemplateId || "", title: document.getElementById("promptTplTitle").value.trim(), category: document.getElementById("promptTplCategory").value.trim(), content: document.getElementById("promptTplContent").value } });
            state.creatingPromptTemplate = false;
          });
          document.getElementById("btnTplDelete").addEventListener("click", () => {
            if (!state.selectedPromptTemplateId) return setStatus("请先选择模板", "err");
            post({ type: "invokeAction", op: "promptTemplateDelete", payload: { id: state.selectedPromptTemplateId } });
          });
          document.getElementById("btnImportTpl").addEventListener("click", () => post({ type: "invokeAction", op: "importPromptTemplates" }));
          document.getElementById("btnExportTpl").addEventListener("click", () => post({ type: "invokeAction", op: "exportPromptTemplates" }));
          document.getElementById("btnReloadTpl").addEventListener("click", () => post({ type: "invokeAction", op: "reloadPromptTemplates" }));
        } else if (state.promptsMainTab === "cursorRules") {
          document.querySelectorAll("[data-rule-tab]").forEach(el => el.addEventListener("click", () => {
            state.data = readFromUI();
            state.cursorRulesTab = el.getAttribute("data-rule-tab");
            render();
          }));
          document.getElementById("btnCursorRulesCopy").addEventListener("click", async () => {
            const text = document.getElementById("cursorRuleContent")?.value || "";
            try {
              await navigator.clipboard.writeText(text);
              setStatus("规则已复制", "ok");
            } catch {
              setStatus("复制失败", "err");
            }
          });
        }
      } else if (state.activeTab === "hotkeys") {
        panel.innerHTML = renderHotkeysTabShell(d);
        bindHotkeysTabHandlers();
        updateHkVkStatusDom(state.data.vkAvailable);
      } else if (state.activeTab === "customize") {
        restoreStudioLlmDraftIfNeeded();
        loadStudioLlmCardsFromLocalStorage();
        const us = state.data.userStudio || d.userStudio || {};
        const llm = us.llm || {};
        const paths = us.paths || {};
        const activeProv = normalizeStudioLlmProvider(llm.provider || "openai");
        const configuredCount = Object.keys(getStudioLlmApiKeys()).length;
        const pathRow = (id, label, val) =>
          `<div class="row"><div class="label">${label}</div><div class="inline" style="flex:1"><input id="usPath_${id}" type="text" data-nosave="1" value="${esc(val || "")}" placeholder="留空则使用系统默认"><button class="btn us-browse" data-us-field="${id}">浏览</button></div></div>`;
        panel.innerHTML = `
${buildStudioPrimaryLlmHtml(us)}
<details class="studio-more" id="studioLocalGatewayDetails"><summary>本机 Gateway（Hermes / OpenClaw）</summary>
<div class="card" style="margin-top:8px">
${buildStudioLocalConnectGridHtml(getStudioLlmCardProviders())}
</div>
</details>
<details class="studio-more"><summary>本机路径与其它（高级）</summary>
<div class="card" style="margin-top:8px"><div class="title">本机路径</div>
${pathRow("cursor", "Cursor.exe", paths.cursor || d.cursorPath || "")}
${pathRow("autohotkey", "AutoHotkey", paths.autohotkey || "")}
<div class="row"><div class="label">备注</div><input id="usPathNotes" type="text" data-nosave="1" value="${esc(paths.notes || "")}"></div>
<div class="inline" style="margin-top:8px">
  <button class="btn" id="btnOpenNiumaChatTtyd">终端定制 (ttyd)</button>
  <button class="btn" id="btnExportUserStudio">导出定制包</button>
  <button class="btn" id="btnImportUserStudio">导入定制包</button>
  <button class="btn" id="btnRestoreUserStudio">还原默认定制</button>
</div>
<div class="hint" style="margin-top:8px;">定制包仅含 user_studio.json；换机请用「存储与缓存 → 数据迁移」。</div>
</details>`;
        bindStudioPrimaryLlmUi();
        bindStudioLocalGatewayUi();
        const proto = studioPrimaryProtocolFromProvider(activeProv);
        if (proto === "hermes" || proto === "openclaw") {
          const det = document.getElementById("studioLocalGatewayDetails");
          if (det) det.open = true;
        }
        document.querySelectorAll(".us-browse").forEach(btn => btn.addEventListener("click", () => {
          post({ type: "browseUserStudioPath", field: btn.getAttribute("data-us-field") });
        }));
        document.getElementById("btnRestoreUserStudio")?.addEventListener("click", async () => {
          const ok = await (window.nmConfirm ? window.nmConfirm(
            "恢复默认配置？",
            "确定恢复默认定制配置？",
            { okLabel: "恢复", cancelLabel: "取消", danger: true }
          ) : Promise.resolve(confirm("确定恢复默认定制配置？")));
          if (!ok) return;
          post({ type: "restoreUserStudio" });
        });
        document.getElementById("btnExportUserStudio")?.addEventListener("click", () => post({ type: "invokeAction", op: "exportUserStudio" }));
        document.getElementById("btnImportUserStudio")?.addEventListener("click", () => post({ type: "invokeAction", op: "importUserStudio" }));
        document.getElementById("btnOpenNiumaChatTtyd")?.addEventListener("click", () => {
          const pl = collectUserStudioPayload();
          const hasKey = !!(String(pl.llm?.apiKey || "").trim());
          if (!hasKey) {
            setStatus("请先填写并保存 API Key", "err");
            return;
          }
          state._ttydAfterStudioSave = { startChat: true };
          post({ type: "saveUserStudio", payload: pl });
          setStatus("正在保存并打开终端定制…", "ok");
        });
      } else if (state.activeTab === "advanced") {
        const aiSec = (Number(d.aiSleepTime || 200) / 1000).toFixed(2).replace(/\.?0+$/, "");
        panel.innerHTML = `<div class="advanced-split">
  <div class="card"><div class="title">高级设置</div>
    <div class="row"><div class="label">界面语言</div><select id="language">${optionsKV([{value:"zh",label:"中文"},{value:"en",label:"英文"}],d.language)}</select></div>
    <div class="row"><div class="label">AI 等待时间 (秒)</div><input id="aiSleepTimeSeconds" type="number" min="0.05" max="10" step="0.05" value="${esc(aiSec)}"></div>
    <div class="row"><div class="label">启动延迟 (秒)</div><input id="launchDelaySeconds" type="number" min="0.5" max="10" step="0.1" value="${esc(d.launchDelaySeconds)}"></div>
  </div>
  <div class="card"><div class="title">配置管理</div>
    <div class="hint" style="margin-bottom:8px;">「导出配置」仅含 CursorShortcut.ini；完整换机请用「存储与缓存 → 数据迁移」。</div>
    <div class="inline"><button class="btn" id="btnExportCfg">导出配置</button><button class="btn" id="btnImportCfg">导入配置</button><button class="btn" id="btnResetCfg">重置默认</button></div></div>
  <div class="card" id="healthSnapshotCard">
    <div class="title">系统健康 <span class="hint" id="healthSnapMeta">只读快照</span></div>
    <div id="healthSnapBody"><div class="hint">正在加载…</div></div>
    <div class="inline" style="margin-top:12px;flex-wrap:wrap;gap:8px;">
      <button type="button" class="btn" id="btnHealthRefresh">刷新快照</button>
      <button type="button" class="btn" id="btnHealthExportDiag">导出诊断包</button>
      <button type="button" class="btn" id="btnHealthOpenLogs">打开日志目录</button>
    </div>
  </div>
</div>`;
        document.getElementById("btnExportCfg").addEventListener("click", () => post({ type: "invokeAction", op: "exportConfig" }));
        document.getElementById("btnImportCfg").addEventListener("click", () => post({ type: "invokeAction", op: "importConfig" }));
        document.getElementById("btnResetCfg").addEventListener("click", () => post({ type: "invokeAction", op: "resetToDefaults" }));
        bindHealthSnapshotHandlers();
      } else if (state.activeTab === "storage") {
        const ci = state.cacheInfo || {};
        const root = esc(ci.root || d.userCacheRoot || "");
        const total = esc(ci.totalText || "计算中…");
        const items = Array.isArray(ci.items) ? ci.items : [];
        const rows = items.length ? items.map(it => `
          <div class="row cache-row">
            <div class="label">${esc(it.label || it.id)}<div class="hint">${esc(it.hint || "")}</div></div>
            <div>
              <div class="inline" style="flex-wrap:wrap;">
                <span class="hint" style="min-width:72px;">${esc(it.sizeText || "0 B")}</span>
                <label class="tag"><input type="checkbox" class="cache-clear-chk" data-cache-id="${esc(it.id)}" checked> 清空</label>
                <button type="button" class="btn cache-open-btn" data-cache-target="${esc(it.id)}">打开</button>
              </div>
              <div class="hint" style="word-break:break-all;margin-top:4px;">${esc(it.path || "")}</div>
            </div>
          </div>`).join("") : `<div class="hint">正在统计缓存占用…</div>`;
        panel.innerHTML = `<div class="card">
  <div class="title">存储与缓存</div>
  <div class="hint">可增长的索引、图片、缩略图与调试日志均在此目录。持久化数据库在 Data/db/，不受此处清空影响。</div>
  <div class="row"><div class="label">缓存根目录</div>
    <div class="inline" style="flex-wrap:wrap;align-items:flex-start;">
      <input id="cacheRootPath" data-nosave="1" type="text" style="min-width:280px;flex:1;" value="${root}" placeholder="默认：项目目录下的 Cache">
      <button type="button" class="btn" id="btnCachePickRoot">更改位置</button>
      <button type="button" class="btn" id="btnCacheOpenRoot">打开文件夹</button>
    </div>
  </div>
  <div class="row"><div class="label">合计占用</div><div><strong id="cacheTotalSize">${total}</strong></div></div>
  ${rows}
  <div class="inline" style="margin-top:12px;flex-wrap:wrap;gap:8px;">
    <button type="button" class="btn" id="btnCacheRefresh">刷新统计</button>
    <button type="button" class="btn primary" id="btnCacheClearSelected">清空所选</button>
    <button type="button" class="btn" id="btnCacheClearAll">清空全部缓存</button>
  </div>
</div>
<div class="card" style="margin-top:12px;">
  <div class="title">数据迁移</div>
  <div class="hint">导出/导入迁移包，用于换机或备份。<strong>不含 API Key</strong>（DPAPI vault 不导出）；导入后请在「智能定制」重新填写 Key。</div>
  <div class="row" style="margin-top:8px;">
    <div class="label">方案</div>
    <select id="migrationPreset" data-nosave="1">${(() => {
      const presets = Array.isArray(state.migrationOptions?.presets) ? state.migrationOptions.presets : [
        { id: "recommended", label: "换机推荐" },
        { id: "light", label: "轻量配置" },
        { id: "full", label: "完整备份" },
        { id: "custom", label: "自定义" }
      ];
      const cur = state.migrationPreset || "recommended";
      return presets.map(p => `<option value="${esc(p.id)}" ${p.id === cur ? "selected" : ""}>${esc(p.label)}${p.description ? " — " + esc(p.description) : ""}</option>`).join("");
    })()}</select>
  </div>
  <div id="migrationGroupsPanel" style="margin-top:4px;">${renderMigrationGroupRows(migrationCurrentSelectedGroups())}</div>
  <div class="hint" id="migrationSelectedSummary" style="margin-top:8px;">${migrationCurrentSelectedGroups().length ? `已选 ${migrationCurrentSelectedGroups().length} 项，约 ${migrationSelectedSizeText(migrationCurrentSelectedGroups())}` : "正在加载…"}</div>
  <div class="inline" style="margin-top:12px;flex-wrap:wrap;gap:8px;">
    <button type="button" class="btn" id="btnMigrationRefresh">刷新统计</button>
    <button type="button" class="btn primary" id="btnMigrationExport">导出迁移包</button>
    <button type="button" class="btn" id="btnMigrationImport">导入迁移包</button>
  </div>
</div>`;
        bindStorageCacheHandlers();
        bindMigrationHandlers();
      } else if (state.activeTab === "screenshot") {
        const ss = { ...(d.screenshotConfig || {}) };
        const capTabs = `<div class="subtabs">
          <button class="subtab-btn ${state.screenshotSubTab === "capture" ? "active" : ""}" data-ss-subtab="capture">截图模式</button>
          <button class="subtab-btn ${state.screenshotSubTab === "output" ? "active" : ""}" data-ss-subtab="output">输出与画质</button>
          <button class="subtab-btn ${state.screenshotSubTab === "ocr" ? "active" : ""}" data-ss-subtab="ocr">OCR</button>
        </div>`;
        let body = "";
        if (state.screenshotSubTab === "capture") {
          body = `<div class="row"><div class="label">捕获模式</div><select id="ssCaptureMode">${optionsKV([
            { value:"selection", label:"区域截图（Win+Shift+S）" },
            { value:"fullscreen", label:"全屏" },
            { value:"active_window", label:"活动窗口" }
          ], ss.captureMode || "selection")}</select></div>
          <div class="row"><div class="label">包含鼠标指针</div><div><input id="ssIncludeCursor" type="checkbox" ${checked(!!ss.includeCursor)}></div></div>
          <div class="row"><div class="label">缩放比例 (%)</div><input id="ssScalePercent" type="number" min="25" max="300" step="5" value="${esc(ss.scalePercent || 100)}"></div>`;
        } else if (state.screenshotSubTab === "output") {
          body = `<div class="row"><div class="label">输出目标</div><select id="ssOutputTarget">${optionsKV([
            { value:"editor", label:"截图助手预览" },
            { value:"clipboard", label:"仅复制到剪贴板" },
            { value:"both", label:"预览 + 剪贴板" }
          ], ss.outputTarget || "editor")}</select></div>
          <div class="row"><div class="label">自动复制到剪贴板</div><div><input id="ssAutoCopyClipboard" type="checkbox" ${checked(ss.autoCopyClipboard !== false)}></div></div>
          <div class="row"><div class="label">保存格式</div><select id="ssImageFormat">${optionsKV([
            { value:"png", label:"PNG（无损）" },
            { value:"jpg", label:"JPG（有损）" },
            { value:"bmp", label:"BMP（大文件）" }
          ], ss.imageFormat || "png")}</select></div>
          <div class="row"><div class="label">JPG 质量 (10-100)</div><input id="ssJpegQuality" type="number" min="10" max="100" step="1" value="${esc(ss.jpegQuality || 90)}"></div>
          <div class="row"><div class="label">保存文件名模板</div><input id="ssFilenamePattern" type="text" value="${esc(ss.saveFilenamePattern || "Screenshot_{yyyyMMdd_HHmmss}")}"></div>
          <div class="hint">可用占位符：<code>{yyyyMMdd_HHmmss}</code></div>`;
        } else {
          const ssOcrEnhanceEnabled = (ss.ocrEnhanceEnabled !== false);
          body = `<div class="row"><div class="label">OCR 文本排版</div><select id="ssOcrLayout">${optionsKV([
            { value:"keep", label:"保持原样" },
            { value:"single_line", label:"合并单行" },
            { value:"multi_line", label:"智能分行" }
          ], ss.ocrTextLayoutMode || "keep")}</select></div>
          <div class="row"><div class="label">OCR 标点处理</div><select id="ssOcrPunc">${optionsKV([
            { value:"keep", label:"保持原样" },
            { value:"halfwidth", label:"转半角" },
            { value:"strip", label:"去除标点" }
          ], ss.ocrPunctuationMode || "keep")}</select></div>
          <div class="row"><div class="label">识别后直接复制</div><div><input id="ssOcrDirectCopy" type="checkbox" ${checked(!!ss.ocrDirectCopyEnabled)}></div></div>
          <div class="row"><div class="label">启用 OCR 增强重试</div><div><input id="ssOcrEnhanceEnabled" type="checkbox" ${checked(ssOcrEnhanceEnabled)}></div></div>
          <div class="row"><div class="label">主缩放倍率 (%)</div><input id="ssOcrScalePrimary" type="number" min="100" max="300" step="10" value="${esc(ss.ocrScalePrimary || 150)}"></div>
          <div class="row"><div class="label">次缩放倍率 (%)</div><input id="ssOcrScaleSecondary" type="number" min="100" max="300" step="10" value="${esc(ss.ocrScaleSecondary || 200)}"></div>
          <div class="row"><div class="label">灰度预处理</div><div><input id="ssOcrUseGrayscale" type="checkbox" ${checked(ss.ocrUseGrayscale !== false)}></div></div>
          <div class="row"><div class="label">二值阈值（低）</div><input id="ssOcrMonoLow" type="number" min="0" max="255" step="1" value="${esc(ss.ocrMonochromeLow || 160)}"></div>
          <div class="row"><div class="label">二值阈值（高）</div><input id="ssOcrMonoHigh" type="number" min="0" max="255" step="1" value="${esc(ss.ocrMonochromeHigh || 175)}"></div>
          <div class="row"><div class="label">深色背景反色重试</div><div><input id="ssOcrUseInvert" type="checkbox" ${checked(ss.ocrUseInvert !== false)}></div></div>`;
        }
        panel.innerHTML = `<div class="card"><div class="title">截图设置</div>${capTabs}${body}</div>`;
        document.querySelectorAll("[data-ss-subtab]").forEach(el => el.addEventListener("click", () => {
          state.data = readFromUI();
          state.screenshotSubTab = el.getAttribute("data-ss-subtab");
          render();
        }));
      } else {
        const selectedDefault = csvToArr(d.searchEngine || "deepseek");
        const selectedAiCli = csvToArr(d.voiceSearchSelectedEnginesCsv || "codex");
        const defaultSummary = selectedDefault.length ? selectedDefault.join(", ") : "请选择搜索引擎";
        const aiCliSummary = selectedAiCli.length ? selectedAiCli.join(", ") : "请选择 AI/CLI 搜索引擎";
        const defaultOptions = DEFAULT_AI_ENGINES.map(e => `<label class="multi-dd-item"><input type="checkbox" data-engine-target="default" value="${esc(e.id)}" ${checked(selectedDefault.includes(e.id))}> <img src="${esc(e.icon)}" alt="${esc(e.label)}"><span>${esc(e.label)}</span></label>`).join("");
        const aiCliOptions = CLI_ENGINES.map(e => `<label class="multi-dd-item"><input type="checkbox" data-engine-target="ai-cli" value="${esc(e.id)}" ${checked(selectedAiCli.includes(e.id))}> <img src="${esc(e.icon)}" alt="${esc(e.label)}"><span>${esc(e.label)}</span></label>`).join("");
        const ft = normalizeFullTextPayload(state.fullText);
        state.fullText = ft;
        const ftCfg = ft.config || {};
        const lightHtml = (ft.engine_lights || ["off","off","off","off"]).map((st, idx) => `<span class="ft-light ${esc(st)}" data-ft-light="${idx}"></span>`).join("");
        const progressNum = Math.max(0, Math.min(100, Number(ft.progress || 0)));
        panel.innerHTML = `<div class="card"><div class="title">搜索设置</div><div class="row"><div class="label">默认搜索引擎（多选）</div><div class="multi-dd" id="ddDefaultEngine"><button type="button" class="multi-dd-btn" id="btnDefaultEngine">${esc(defaultSummary)}</button><div class="multi-dd-panel">${defaultOptions}</div></div></div><div class="row"><div class="label">AI/CLI 搜索引擎（多选）</div><div class="multi-dd" id="ddAiCliEngine"><button type="button" class="multi-dd-btn" id="btnAiCliEngine">${esc(aiCliSummary)}</button><div class="multi-dd-panel">${aiCliOptions}</div></div></div><div class="row"><div class="label">自动加载选中文本</div><div><input id="autoLoadSelectedText" type="checkbox" ${checked(d.autoLoadSelectedText)}></div></div><div class="row"><div class="label">自动更新语音输入</div><div><input id="autoUpdateVoiceInput" type="checkbox" ${checked(d.autoUpdateVoiceInput)}></div></div><div class="label">启用分类</div><div class="tag-wrap">${catRows}</div></div>
<div class="card">
  <div class="title">全文索引控制台</div>
  <div class="ft-console">
    <div class="ft-title">引擎状态</div>
    <div class="ft-light-row">${lightHtml}<span id="ftSummary" class="ft-kv">${ft.running ? "运行中" : "已停止"} · ${ft.ready ? "已就绪" : "构建中"} · ${esc(ft.progressText || "0.0%")}</span><span id="ftVersion" class="ft-kv">索引版本 ${esc(ft.indexVersion || "-")}</span></div>
    <div class="ft-progress"><div id="ftProgressBar" class="ft-progress-bar" style="width:${progressNum.toFixed(1)}%"></div></div>
    <div id="ftCurrentFile" class="ft-file" title="${esc(buildFullTextTaskText(ft))}">${esc(buildFullTextTaskText(ft))}</div>
    <div class="inline" style="margin-top:10px;">
      <button class="btn" id="btnFtToggle">启动索引</button>
      <button class="btn" id="btnFtRebuild">强制重建索引</button>
      <button class="btn" id="btnFtRefresh">刷新状态</button>
      <button class="btn" id="btnFtProbe">检测可行性</button>
      <button class="btn" id="btnFtRecommend">应用推荐方式</button>
      <button class="btn" id="btnFtRoots">重新选择索引范围</button>
    </div>
    <div class="ft-mode-grid">
      <select id="ftScanScheme" data-nosave="1" title="扫描方式">
        <option value="auto"${(ftCfg.scanScheme||"auto")==="auto"?" selected":""}>自动选择（推荐）</option>
        <option value="mft"${ftCfg.scanScheme==="mft"?" selected":""}>高速扫描（推荐）</option>
        <option value="everything"${ftCfg.scanScheme==="everything"?" selected":""}>快速扫描（需 Everything）</option>
        <option value="walk"${ftCfg.scanScheme==="walk"?" selected":""}>兼容扫描（最稳定）</option>
      </select>
      <label class="inline"><input id="ftUseUSN" data-nosave="1" type="checkbox" ${checked(ftCfg.useUSN !== false)}> 实时更新</label>
      <span id="ftProbeSummary" class="ft-probe-summary"></span>
    </div>
    <div id="ftProbeList" class="ft-probe-list"></div>
    <div class="row" style="margin-top:10px;">
      <div class="label">索引存储目录</div>
      <div class="inline"><input id="ftIndexDir" data-nosave="1" type="text" value="${esc(ftCfg.indexDir || "")}" placeholder="默认：项目 Cache\\fulltext-index"><button class="btn" id="btnFtPickDir" type="button">选择目录</button></div>
      <div class="hint">索引默认存放在「存储与缓存」中的全文索引目录；清空缓存后需重建索引。</div>
    </div>
    <div class="row"><div class="label">后台自启动索引</div><div><input id="ftAutoStart" data-nosave="1" type="checkbox" ${checked(ftCfg.autoStart !== false)}></div></div>
    <div class="row"><div class="label">多线程并发（Worker Pool）</div><div><input id="ftWorkers" data-nosave="1" type="number" min="1" max="32" step="1" value="${esc(ftCfg.workers || 2)}"></div></div>
    <div class="row"><div class="label">扫描速度策略</div><div><select id="ftScanSpeed" data-nosave="1"><option value="slow"${ftCfg.scanSpeed==="slow"?" selected":""}>slow</option><option value="normal"${ftCfg.scanSpeed==="normal"?" selected":""}>normal</option><option value="fast"${ftCfg.scanSpeed==="fast"?" selected":""}>fast</option></select></div></div>
    <div class="row"><div class="label">初次扫描延迟（秒）</div><div><input id="ftInitialDelay" data-nosave="1" type="number" min="1" max="120" step="1" value="${esc(ftCfg.initialDelaySec || 1)}"></div></div>
    <div class="row"><div class="label">单文件间隔（ms）</div><div><input id="ftPauseMS" data-nosave="1" type="number" min="0" max="100" step="1" value="${esc(ftCfg.pauseMS ?? 5)}"></div></div>
    <div class="row"><div class="label">超大文本扫描</div><div class="inline"><input id="ftIncludeLarge" data-nosave="1" type="checkbox" ${checked(ftCfg.includeLargeText)}><span class="ft-kv">允许扫描超过 2MB 文本</span></div></div>
    <div class="row"><div class="label">超大文本大小上限（MB）</div><div><input id="ftMaxFileMB" data-nosave="1" type="number" min="1" max="512" step="1" value="${esc(ftCfg.maxFileSizeMB || 8)}"></div></div>
    <div id="ftHint" class="hint">${ft.lastError ? esc(ft.lastError) : "更改会保存并应用到索引引擎；与索引无关的选项请使用上方「搜索设置」卡片。"}</div>
  </div>
</div>`;
        const bindDropdown = (wrapId, btnId, target) => {
          const wrap = document.getElementById(wrapId);
          const btn = document.getElementById(btnId);
          btn.addEventListener("click", () => wrap.classList.toggle("open"));
          wrap.querySelectorAll(`input[data-engine-target="${target}"]`).forEach(chk => chk.addEventListener("change", () => {
            const vals = Array.from(wrap.querySelectorAll(`input[data-engine-target="${target}"]:checked`)).map(el => el.value);
            btn.textContent = vals.length ? vals.join(", ") : (target === "default" ? "请选择搜索引擎" : "请选择 AI/CLI 搜索引擎");
          }));
          document.addEventListener("click", (e) => { if (!wrap.contains(e.target)) wrap.classList.remove("open"); });
        };
        bindDropdown("ddDefaultEngine", "btnDefaultEngine", "default");
        bindDropdown("ddAiCliEngine", "btnAiCliEngine", "ai-cli");
        bindFullTextConsoleControls();
        refreshFullTextConsoleDom();
      }
      bindAutoSaveControls();
      runLazyInitForTab(state.activeTab, "render");
      trace("render_end", "", { tab: state.activeTab });
    }
    function validate(d) {
      if (!d.cursorPath) return "Cursor 路径不能为空";
      if (!(d.capslockHoldTimeSeconds >= 0.1 && d.capslockHoldTimeSeconds <= 5.0)) return "CapsLock Hold Time 需要在 0.1 到 5.0 之间";
      if (!Number.isInteger(d.popupScreenIndex) || d.popupScreenIndex < 1) return "弹窗屏幕序号非法";
      const maxMonitors = Math.max(1, Number(d.monitorCount || 1));
      if (d.popupScreenIndex > maxMonitors) return "弹窗屏幕序号超出显示器范围";
      if (!["cursor","fixed","edge"].includes(String(d.holePlacementPreset || "cursor"))) return "黑洞出现位置非法";
      const trigErr = validateHoleTriggers(d);
      if (trigErr) return trigErr;
      if (![1000, 3000, 5000].includes(normalizeHoleRButtonHoldMs(d.holeRButtonHoldMs))) return "长按右键时长非法";
      if (!["anchor","fixed","relative"].includes(String(d.holePositionMode || "anchor"))) return "黑洞位置模式非法";
      if (!Number.isFinite(Number(d.holeTriggerDistance)) || Number(d.holeTriggerDistance) < 80 || Number(d.holeTriggerDistance) > 1200) return "黑洞触发距离非法";
      if (!Number.isFinite(Number(d.holeDismissDistance)) || Number(d.holeDismissDistance) < 120 || Number(d.holeDismissDistance) > 1600) return "黑洞消失距离非法";
      if (!Number.isFinite(Number(d.holeSizeScale)) || Number(d.holeSizeScale) < 0.85 || Number(d.holeSizeScale) > 1.5) return "黑洞大小非法";
      if (!["ring","starry"].includes(String(d.holeVisualStyle || "ring"))) return "黑洞样式非法";
      if (!["right","left","top","bottom"].includes(String(d.holeHideDockEdge || "right"))) return "黑洞隐藏吸附边缘非法";
      if (!Number.isFinite(Number(d.holeHideDockMargin)) || Number(d.holeHideDockMargin) < 0 || Number(d.holeHideDockMargin) > 80) return "黑洞隐藏吸附边距非法";
      if (!Number.isInteger(d.aiSleepTime) || d.aiSleepTime < 50) return "AI 等待时间非法";
      if (!(d.launchDelaySeconds >= 0.5 && d.launchDelaySeconds <= 10)) return "启动延迟时间非法";
      return "";
    }
    function __settingsBindTabButtons() {
      document.querySelectorAll("#sidebar .tab-btn, #child-subnav .tab-btn").forEach(btn => btn.addEventListener("click", () => {
      const nextTab = btn.dataset.tab;
      if (nextTab !== state.activeTab) leaveActiveTab(state.activeTab);
      try { state.data = readFromUI(); } catch (_) {}
      state.activeTab = nextTab;
      try { sessionStorage.setItem("settings.activeTab", nextTab); } catch (_) {}
      if (nextTab === "storage") state.cacheInfo = null;
      document.querySelectorAll(".tab-btn").forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
      render();
      runLazyInitForTab(state.activeTab, "tab_click");
    }));
    }
    __settingsBindTabButtons();
    const panelRoot = document.getElementById("panel");
    panelRoot.addEventListener("input", (e) => {
      const t = e.target;
      if (!t || !(t.matches?.("input,textarea,select"))) return;
      if (t.name === "activationMode") return;
      if (t.dataset?.nosave === "1") return;
      patchSettingsControl(t);
      if (t.id === "popupScreenIndex") {
        state.data.popupScreenIndex = Number(t.value);
        postSavePopupScreen();
        return;
      }
      if (t.id === "autoStart" || t.id === "holdTime" || t.id === "cursorPath") {
        postSaveGeneral({ [t.id === "holdTime" ? "capslockHoldTimeSeconds" : t.id]: t.id === "autoStart" ? !!t.checked : (t.id === "holdTime" ? Number(t.value) : t.value.trim()) });
        return;
      }
      scheduleSettingsPersist(true);
    });
    panelRoot.addEventListener("change", (e) => {
      const t = e.target;
      if (t && t.name === "activationMode") {
        state.appearanceActivationMode = normalizeActivationMode(t.value);
        state.data.appearanceActivationMode = state.appearanceActivationMode;
        saveAppearanceActivationMode();
        if (activationModeSaveTimer) clearTimeout(activationModeSaveTimer);
        activationModeSaveTimer = 0;
        post({ type: "saveAppearanceActivationMode", mode: state.appearanceActivationMode });
        return;
      }
      if (!t || !(t.matches?.("input,textarea,select"))) return;
      if (t.id === "themeMode") {
        state.data.themeMode = t.value;
        applyWebTheme(t.value);
        try { localStorage.setItem("settings_themeMode", t.value); } catch (_) {}
        post({ type: "saveThemeMode", themeMode: t.value });
        return;
      }
      if (t.id === "popupScreenIndex") {
        state.data.popupScreenIndex = Number(t.value);
        postSavePopupScreen();
        return;
      }
      if (t.id === "defaultStartTab") {
        const tab = normalizeDefaultStartTab(t.value);
        state.data.defaultStartTab = tab;
        defaultStartTabDirty = true;
        post({ type: "saveDefaultStartTab", tab });
        return;
      }
      patchSettingsControl(t);
      if (t.id === "autoStart") {
        postSaveGeneral({ autoStart: !!t.checked });
        return;
      }
      if (t.id === "holdTime") {
        postSaveGeneral({ capslockHoldTimeSeconds: Number(t.value) });
        return;
      }
      if (t.dataset?.nosave === "1") return;
      scheduleSettingsPersist(true);
    });
    document.getElementById("btn-cancel").addEventListener("click", () => {
      leaveActiveTab(state.activeTab);
      flushStudioLlmPending();
      flushSettingsTab();
      post({ type: "cancel" });
    });
    document.getElementById("btn-save").addEventListener("click", () => {
      leaveActiveTab(state.activeTab);
      flushStudioLlmPending();
      const d = pruneSettingsPayload(readFromUI());
      const err = validatePayload(d);
      if (err) return setStatus(err, "err");
      if (!Object.keys(d).length) return setStatus("当前页无可保存项", "err");
      post({ type: "saveSettings", payload: d });
    });
    document.addEventListener("keydown", (e) => {
      if (e.key !== "Escape") return;
      if (state.hkRecording && state.activeTab === "hotkeys") {
        e.preventDefault();
        stopHotkeyRecording();
        render();
        return;
      }
      e.preventDefault();
      post({ type: "cancel" });
    });
    function handleHostMessage(msg) {
      if (!msg || !msg.type) return;
      if (msg.type === "initData") {
        trace("initdata_begin", "", { navigateToStartTab: !!msg.navigateToStartTab });
        suppressAutoSave = true;
        const p = msg.payload || {};
        const shouldNavigate = !!msg.navigateToStartTab;
        const serverStartTab = normalizeDefaultStartTab(p.defaultStartTab);
        const pForMerge = { ...p };
        if (!shouldNavigate) delete pForMerge.defaultStartTab;
        let cachedTheme = "";
        try {
          const c = localStorage.getItem("settings_themeMode");
          if (c === "light" || c === "dark") cachedTheme = c;
        } catch (_) {}
        const incomingTheme = (typeof p.themeMode === "string" && p.themeMode) ? p.themeMode : "";
        state.data = {
          ...state.data,
          ...pForMerge,
          cursorShortcuts: (Array.isArray(p.cursorShortcuts) && p.cursorShortcuts.length)
            ? p.cursorShortcuts
            : DEFAULT_CURSOR_SHORTCUTS
        };
        mergeCursorShortcutsAsSuggested(state.data.cursorShortcuts);
        state.data.summonHotkeyPreset = "capslock";
        state.data.summonHotkeyCustom = "";
        if (String(state.data.capsLockMode || "chord") === "off")
          state.data.capsLockHoldVkEnabled = false;
        state.data.themeMode = incomingTheme || cachedTheme || state.data.themeMode || "dark";
        // 持久化到 localStorage，下次打开时立即应用，无需等 AHK 推送
        try { localStorage.setItem("settings_themeMode", state.data.themeMode); } catch (_) {}
        state.appearanceActivationMode = normalizeActivationMode(p.appearanceActivationMode || state.appearanceActivationMode);
        state.data.appearanceActivationMode = state.appearanceActivationMode;
        saveAppearanceActivationMode();
        if (Array.isArray(p.keybinderToolbarLayout)) state.data.keybinderToolbarLayout = normalizeToolbarLayoutRows(p.keybinderToolbarLayout);
        if (Array.isArray(p.keybinderCommands)) state.data.keybinderCommands = p.keybinderCommands;
        if (Array.isArray(p.keybinderContextMenuLayout)) state.data.keybinderContextMenuLayout = p.keybinderContextMenuLayout;
        mergeKeybinderBindingsFromHost(p.keybinderBindings, p.keybinderSuggestedBindings);
        if (p.userStudio && typeof p.userStudio === "object") {
          if (Array.isArray(p.userStudio.options?.llmCardProviders))
            state._studioCardsExplicit = true;
          mergeUserStudioStateFromServer(p.userStudio);
        }
        if (!Array.isArray(state.data.userStudio?.options?.llmCardProviders))
          loadStudioLlmCardsFromLocalStorage();
        if (p.appUpdate && typeof p.appUpdate === "object") state.appUpdate = p.appUpdate;
        applyAppUpdateUi();

        if (__SETTINGS_SCOPE__ && Array.isArray(__SETTINGS_SCOPE__.tabs)) {
          const allowed = new Set(__SETTINGS_SCOPE__.tabs);
          if (!allowed.has(state.activeTab)) state.activeTab = __SETTINGS_SCOPE__.tabs[0];
        }
        if (shouldNavigate) {
          if (state.hotkeysSubTab === "niuma" || state.hotkeysSubTab === "qa") state.hotkeysSubTab = "overview";
          state.activeTab = serverStartTab;
          try { sessionStorage.setItem("settings.activeTab", serverStartTab); } catch (_) {}
          document.querySelectorAll(".tab-btn").forEach(b => b.classList.toggle("active", b.dataset.tab === serverStartTab));
        } else if (initDataReceived) {
          /* 同一会话内后续 initData 仅刷新数据，恢复用户上次点的侧栏标签 */
          try {
            const lastTab = sessionStorage.getItem("settings.activeTab");
            const valid = new Set(["general","appearance","prompts","hotkeys","advanced","storage","screenshot","search","customize"]);
            if (lastTab && valid.has(lastTab)) {
              state.activeTab = lastTab;
              document.querySelectorAll(".tab-btn").forEach(b => b.classList.toggle("active", b.dataset.tab === lastTab));
            }
          } catch (_) {}
        }
        if (typeof msg.payload?.vkAvailable === "boolean")
          state.data.vkAvailable = msg.payload.vkAvailable;
        updateHkVkStatusDom(state.data.vkAvailable);
        const ids = (state.data.promptTemplateSummary || []).map(t => t.id);
        if (state.selectedPromptTemplateId && !ids.includes(state.selectedPromptTemplateId))
          state.selectedPromptTemplateId = "";
        render();
        setStatus("已连接", "ok");
        lastSavedHash = stableStringify(pruneSettingsPayload(readFromUI()));
        lastSentHash = lastSavedHash;
        pendingSaveHash = "";
        saveInFlight = false;
        initDataReceived = true;
        trace("initdata_end", "", { activeTab: state.activeTab });
        if (__SETTINGS_CHILD__) {
          try {
            window.parent.postMessage({ channel: "nmer-settings-child-lifecycle", stage: "init_applied" }, "*");
          } catch (_) {}
        }
        setTimeout(() => { suppressAutoSave = false; }, 0);
        runLazyInitForTab(state.activeTab, "initData");
        return;
      }
      if (msg.type === "vkStatus") {
        state.data.vkAvailable = !!msg.available;
        updateHkVkStatusDom(state.data.vkAvailable);
        return;
      }
      if (msg.type === "vkWebEvent" && msg.event) {
        handleVkWebEvent(msg.event);
        return;
      }
      if (msg.type === "keybinderBindingsSnapshot") {
        mergeKeybinderBindingsFromHost(msg.bindings, msg.suggestedBindings);
        if (state.activeTab === "hotkeys") render();
        return;
      }
      if (msg.type === "keybinderCatalogSnapshot") {
        if (mergeKeybinderCatalogFromHost(msg) && state.activeTab === "hotkeys") render();
        return;
      }
      if (msg.type === "browseCursorPathResult" && msg.path) { state.data.cursorPath = msg.path; render(); return; }
      if (msg.type === "browseUserStudioPathResult" && msg.path) {
        const field = String(msg.field || "");
        const el = document.getElementById("usPath_" + field);
        if (el) el.value = msg.path;
        return;
      }
      if (msg.type === "hermes_gateway_restart_result") {
        if (studioHermesRestartPending) {
          studioHermesRestartPending.resolve({
            ok: !!msg.ok,
            error: String(msg.error || "").trim(),
            elapsedMs: msg.elapsedMs
          });
          return;
        }
        setStatus(msg.ok ? "Hermes Gateway 已重启" : (msg.error || "重启失败"), msg.ok ? "ok" : "err");
        return;
      }
      if (msg.type === "hermes_studio_status" || msg.type === "hermes_host_token_probe") {
        const payload = {
          token: String(msg.token || "").trim(),
          source: String(msg.source || "").trim(),
          host: String(msg.host || "127.0.0.1").trim(),
          port: Number(msg.port) || 8642,
          apiEnabled: !!msg.apiEnabled,
          gatewayOk: msg.gatewayOk,
          gatewayError: String(msg.gatewayError || "").trim(),
          debug: String(msg.debug || "").trim(),
          installKind: String(msg.installKind || "none"),
          installLabel: String(msg.installLabel || "").trim(),
          apiServerState: String(msg.apiServerState || "").trim(),
          canRestartGateway: !!msg.canRestartGateway,
          force: !!msg.force
        };
        if (studioHermesImportPending) {
          studioHermesImportPending.resolve(payload);
          return;
        }
        applyStudioHermesStatusPayload(payload);
        state.studioHermesStatus = state.studioHermesStatus || {};
        state.studioHermesStatus.token = payload.token;
        state.studioHermesStatus.source = payload.source;
        state.studioHermesStatus.canRestartGateway = payload.canRestartGateway;
        updateStudioHermesQuickStatusDom();
        updateStudioHermesRestartBtn();
        const modalHm = document.getElementById("studioLlmAddModal");
        const modalHmOpen = modalHm?.classList.contains("open");
        if (modalHmOpen && payload.token && normalizeStudioLlmProvider(document.getElementById("studioModalProvider")?.value) === "hermes") {
          const keyElHm = document.getElementById("studioModalApiKey");
          if (keyElHm) {
            keyElHm.value = payload.token;
            keyElHm.type = "text";
          }
          setStatus("已从本机填入 API_SERVER_KEY，可点「一键连接」完成保存。", "ok");
        }
        return;
      }
      if (msg.type === "openclaw_studio_status" || msg.type === "openclaw_host_token_probe") {
        const payload = {
          token: String(msg.token || "").trim(),
          niumaToken: String(msg.niumaToken || "").trim(),
          source: String(msg.source || "").trim(),
          host: String(msg.host || "127.0.0.1").trim(),
          port: Number(msg.port) || 18789,
          gatewayOk: msg.gatewayOk,
          gatewayError: String(msg.gatewayError || "").trim(),
          debug: String(msg.debug || "").trim(),
          force: !!msg.force,
          reqId: String(msg.reqId || "").trim()
        };
        if (payload.reqId && finishStudioOpenClawPending(payload.reqId, payload, null)) return;
        if (studioOpenClawImportPending) {
          finishStudioOpenClawPending(studioOpenClawImportPending.reqId, payload, null);
          return;
        }
        applyStudioOpenClawStatusPayload(payload);
        state.studioOpenClawStatus = state.studioOpenClawStatus || {};
        state.studioOpenClawStatus.token = payload.token;
        state.studioOpenClawStatus.source = payload.source;
        updateStudioOpenClawQuickStatusDom();
        const modal = document.getElementById("studioLlmAddModal");
        const modalOpen = modal?.classList.contains("open");
        if (modalOpen && payload.token && normalizeStudioLlmProvider(document.getElementById("studioModalProvider")?.value) === "openclaw") {
          const keyEl = document.getElementById("studioModalApiKey");
          if (keyEl) {
            keyEl.value = payload.token;
            keyEl.type = "text";
          }
          setStatus("已从本机填入 Gateway Token，可点「一键连接」完成保存。", "ok");
        }
        return;
      }
      if (msg.type === "testUserStudioLlmAck") {
        return;
      }
      if (msg.type === "testUserStudioLlmResult") {
        state._studioTestInFlight = false;
        if (msg.async && msg.ok && !msg.error && msg.elapsedMs == null) return;
        const expectId = String(state._studioTestAckId || "").trim();
        const gotId = String(msg.testId || "").trim();
        if (expectId && gotId && expectId !== gotId) return;
        const ms = msg.elapsedMs ? `（${msg.elapsedMs}ms）` : "";
        let testErr = "";
        if (isLlmManagerEnabled() && state.data.userStudio) {
          if (!state.data.userStudio.llmUnified) state.data.userStudio.llmUnified = {};
          state.data.userStudio.llmUnified.testStatus = {
            ok: !!msg.ok,
            message: String(msg.error || "").trim()
          };
        }
        if (state._studioTestWaiter) {
          const waiter = state._studioTestWaiter;
          state._studioTestWaiter = null;
          state._studioTestAckId = "";
          const result = {
            ok: !!msg.ok,
            error: summarizeStudioLlmTestError(msg.error, msg.provider, msg.endpoint, msg.diagnostics, msg),
            elapsedMs: msg.elapsedMs,
            baseUrl: String(msg.baseUrl || "").trim(),
            model: String(msg.model || "").trim(),
            provider: String(msg.provider || "").trim(),
            endpoint: String(msg.endpoint || "").trim(),
            diagnostics: String(msg.diagnostics || "").trim(),
            phase: String(msg.phase || "").trim(),
            status: Number(msg.status || 0)
          };
          if (!result.ok) setStatus(result.error, "err");
          waiter(result);
          return;
        }
        if (msg.ok) {
          setStatus(`API 测试通过${ms}`, "ok");
        } else {
          testErr = summarizeStudioLlmTestError(msg.error, msg.provider, msg.endpoint, msg.diagnostics, msg);
          setStatus(testErr, "err");
        }
        const testProv = String(state._studioLastTestProv || "").trim();
        state._studioLastTestProv = "";
        if (testProv === "hermes") {
          studioHermesMarkConnVerified(!!msg.ok);
          if (msg.ok) setStatus(`Hermes API 测试通过${ms}`, "ok");
          else setStatus(testErr || String(msg.error || "").trim() || "API 测试失败", "err");
          return;
        }
        if (msg.ok) {
          captureCustomizeTabState();
          if (state.activeTab === "customize") render();
        }
        return;
      }
      if (msg.type === "saveUserStudioResult") {
        studioLlmPersistInFlight = false;
        const silent = !!state._studioLlmPersistSilent;
        state._studioLlmPersistSilent = false;
        if (!silent) {
          setStatus(msg.ok ? "智能定制已保存" : (msg.error || "保存失败"), msg.ok ? "ok" : "err");
          if (msg.ok && state.activeTab === "customize") render();
        }
        if (msg.ok && msg.userStudio && typeof msg.userStudio === "object") {
          mergeUserStudioStateFromServer(msg.userStudio);
        } else if (msg.ok) {
          saveStudioLlmCardsToLocalStorage(buildStudioLlmPersistPayload());
        }
        if (studioLlmPersistQueued) {
          studioLlmPersistQueued = false;
          setTimeout(() => flushStudioLlmPending(), 50);
        }
        if (msg.ok && state._ttydAfterStudioSave) {
          const opts = state._ttydAfterStudioSave;
          state._ttydAfterStudioSave = null;
          post({
            type: "invokeAction",
            op: "openNiumaChatTtyd",
            startChat: !!opts.startChat,
            payload: collectUserStudioPayload()
          });
        }
        return;
      }
      if (msg.type === "restoreUserStudioResult") {
        setStatus(msg.ok ? "已恢复默认定制配置" : (msg.error || "还原失败"), msg.ok ? "ok" : "err");
        if (msg.ok) {
          try {
            sessionStorage.removeItem("niuma_studio_llm_draft");
          } catch (_) {}
          if (msg.userStudio && typeof msg.userStudio === "object") mergeUserStudioStateFromServer(msg.userStudio);
          if (state.activeTab === "customize") render();
        }
        return;
      }
      if (msg.type === "appUpdateStatus") {
        if (msg.payload && typeof msg.payload === "object") state.appUpdate = msg.payload;
        applyAppUpdateUi();
        const u = normalizeAppUpdate(state.appUpdate);
        if (u.hasUpdate) setStatus(`发现新版本 ${u.latestVersion || ""}，点击侧栏或「前往 GitHub」下载`, "ok");
        else setStatus("当前已是最新版本", "ok");
        if (state.activeTab === "general") render();
        return;
      }
      if (msg.type === "openAppReleaseResult" && !msg.ok) {
        setStatus(msg.error || "无法打开 GitHub", "err");
        return;
      }
      if (msg.type === "openNiumaChatTtydResult" && !msg.ok) {
        setStatus(msg.error || "无法打开 Niuma Chat", "err");
        return;
      }
      if (msg.type === "openNiumaChatAskResult" && !msg.ok) {
        setStatus(msg.error || "无法打开 Niuma Chat", "err");
        return;
      }
      if (msg.type === "loadNiumaProjectBriefResult") {
        const el = document.getElementById("studioNiumaSystemPrompt");
        const hint = document.getElementById("niumaBriefPreviewHint");
        if (msg.ok && el) el.value = String(msg.text || "");
        if (hint) hint.textContent = msg.ok ? "已载入内置 Brief，保存 API 后生效。" : (msg.error || "载入失败");
        setStatus(msg.ok ? "已载入项目 Brief" : (msg.error || "载入失败"), msg.ok ? "ok" : "err");
        return;
      }
      if (msg.type === "syncNiumaChatLlmResult") {
        if (msg.ok && msg.userStudio) mergeUserStudioStateFromServer(msg.userStudio);
        const silent = !!state._studioSyncSilent;
        state._studioSyncSilent = false;
        if (msg.ok) {
          if (!silent) setStatus("已从 Niuma Chat 同步 API", "ok");
          if (state.activeTab === "customize") {
            render();
            refreshStudioHermesStatusAsync();
            refreshStudioOpenClawStatusAsync();
          }
        } else if (state._studioSyncManual) {
          setStatus(msg.error || "同步失败", "err");
        } else if (silent && state.activeTab === "customize") {
          refreshStudioHermesStatusAsync();
          refreshStudioOpenClawStatusAsync();
        }
        state._studioSyncManual = false;
        return;
      }
      if (msg.type === "cacheInfo") {
        state.cacheInfo = {
          root: String(msg.root || ""),
          totalBytes: Number(msg.totalBytes || 0),
          totalText: String(msg.totalText || ""),
          items: Array.isArray(msg.items) ? msg.items : []
        };
        if (state.activeTab === "storage") render();
        else setStatus("缓存统计已更新", "ok");
        return;
      }
      if (msg.type === "cacheClearResult") {
        const cleared = Array.isArray(msg.cleared) ? msg.cleared : [];
        setStatus(cleared.length ? ("已清空：" + cleared.join("、")) : "未清空任何项", cleared.length ? "ok" : "err");
        if (state.activeTab === "storage") requestCacheInfo();
        return;
      }
      if (msg.type === "cacheSaveRootResult") {
        if (msg.ok) {
          state.data.userCacheRoot = String(msg.path || "");
          setStatus("缓存目录已更新", "ok");
          state.cacheInfo = null;
          if (state.activeTab === "storage") render();
        } else {
          setStatus(msg.error || "缓存目录保存失败", "err");
        }
        return;
      }
      if (msg.type === "cacheRootPicked") {
        if (!msg.ok || !msg.path) return;
        const el = document.getElementById("cacheRootPath");
        if (el) el.value = String(msg.path);
        const doMove = () => {
          setStatus("正在迁移缓存…", "");
          post({ type: "cacheSaveRoot", path: String(msg.path) });
        };
        if (window.nmConfirm) {
          window.nmConfirm(
            "迁移缓存目录？",
            "将缓存迁移到新目录并保存？迁移期间请勿关闭设置窗口。",
            { okLabel: "迁移并保存", cancelLabel: "取消" }
          ).then((ok) => { if (ok) doMove(); });
          return;
        }
        if (!confirm("将缓存迁移到新目录并保存？迁移期间请勿关闭设置窗口。")) return;
        doMove();
        return;
      }
      if (msg.type === "fulltextStatus") {
        state.fullText = normalizeFullTextPayload(msg.payload || {});
        refreshFullTextConsoleDom();
        return;
      }
      if (msg.type === "fulltextConfigResult") {
        setStatus(msg.ok ? "全文索引配置已应用" : (msg.error || "全文索引配置失败"), msg.ok ? "ok" : "err");
        requestFullTextStatus(true);
        return;
      }
      if (msg.type === "fulltextActionResult") {
        if (msg.ok && (msg.action === "rebuild" || msg.action === "fullsync")) {
          setStatus("强制重建已启动，单字检索将在新索引中生效", "ok");
        } else {
          setStatus(msg.ok ? "全文索引操作成功" : (msg.error || "全文索引操作失败"), msg.ok ? "ok" : "err");
        }
        requestFullTextStatus(true);
        return;
      }
      if (msg.type === "fulltextBrowseResult") {
        const path = String(msg.path || "").trim();
        if (!path) return;
        const el = document.getElementById("ftIndexDir");
        if (el) {
          el.value = path;
          scheduleFullTextApply(10);
        }
        return;
      }
      if (msg.type === "fulltextProbeResult") {
        state.fullTextProbe.busy = false;
        if (msg.ok) {
          renderFullTextProbe(msg.probe || {});
          setStatus("可行性检测完成", "ok");
        } else {
          setFullTextProbeSummary(msg.error || "可行性检测失败");
          setStatus(msg.error || "可行性检测失败", "err");
        }
        return;
      }
      if (msg.type === "saveResult") {
        saveInFlight = false;
        if (msg.ok) {
          lastSavedHash = lastSentHash || stableStringify(readFromUI());
          if (pendingSaveHash && pendingSaveHash !== lastSavedHash) {
            scheduleSettingsPersist(true);
          }
        } else if (msg.error) {
          setStatus(msg.error, "err");
        }
        return;
      }
      if (msg.type === "saveAppearanceActivationModeResult") {
        setStatus(msg.ok ? ("激活方式已生效：" + (ACTIVATION_MODE_OPTIONS.find(o => o.value === msg.mode)?.label || msg.mode || "悬浮栏")) : (msg.error || "激活方式切换失败"), msg.ok ? "ok" : "err");
        return;
      }
      if (msg.type === "saveThemeModeResult") {
        if (msg.ok && msg.themeMode) {
          state.data.themeMode = msg.themeMode;
          applyWebTheme(msg.themeMode);
          try { localStorage.setItem("settings_themeMode", msg.themeMode); } catch (_) {}
        }
        setStatus(msg.ok ? (msg.themeMode === "light" ? "已切换为浅色主题" : "已切换为深色主题") : (msg.error || "主题保存失败"), msg.ok ? "ok" : "err");
        return;
      }
      if (msg.type === "saveDefaultStartTabResult") {
        if (msg.ok && msg.tab) {
          state.data.defaultStartTab = normalizeDefaultStartTab(msg.tab);
          defaultStartTabDirty = false;
          lastSavedHash = stableStringify(pruneSettingsPayload(readFromUI()));
          lastSentHash = lastSavedHash;
        } else if (msg.error) {
          setStatus(msg.error, "err");
        }
        return;
      }
      if (msg.type === "savePopupScreenIndexResult") {
        if (msg.ok && msg.popupScreenIndex) {
          state.data.popupScreenIndex = Number(msg.popupScreenIndex);
          setStatus(`弹窗位置已保存（显示器 ${msg.popupScreenIndex}）`, "ok");
        } else {
          setStatus(msg.error || "弹窗位置保存失败", "err");
        }
        return;
      }
      if (msg.type === "saveGeneralSettingsResult") {
        if (msg.ok) {
          captureGeneralTabState();
          lastSavedHash = stableStringify(pruneSettingsPayload(readFromUI()));
          lastSentHash = lastSavedHash;
          if (state.data.autoStart) setStatus("开机自启动已写入注册表", "ok");
          else setStatus("已关闭开机自启动", "ok");
        } else {
          setStatus(msg.error || "注册表自启动写入失败", "err");
        }
        return;
      }
      if (msg.type === "saveKeybinderToolbarLayoutResult") {
        setStatus(msg.ok ? "工具栏与右键菜单已写入配置" : (msg.error || "保存失败"), msg.ok ? "ok" : "err");
        return;
      }
      if (msg.type === "previewHoleResult") {
        setStatus(msg.ok ? "已在屏幕上预览黑洞（约 3 秒）" : (msg.error || "预览失败"), msg.ok ? "ok" : "err");
        return;
      }
      if (msg.type === "saveHoleResult") {
        if (msg.ok) {
          const saved = (msg.saved && typeof msg.saved === "object") ? msg.saved : collectHoleSettingsPayload(readFromUI());
          state.data = { ...state.data, ...saved };
          lastSavedHash = stableStringify(state.data);
          lastSentHash = lastSavedHash;
        }
        setStatus(msg.ok ? "黑洞设置已保存" : (msg.error || "黑洞设置保存失败"), msg.ok ? "ok" : "err");
        return;
      }
      if (msg.type === "healthSnapshot") {
        state.healthSnapshot = (msg.payload && typeof msg.payload === "object") ? msg.payload : null;
        state.healthSnapshotLoading = false;
        if (state.activeTab === "advanced") renderHealthSnapshotDom(state.healthSnapshot, false);
        return;
      }
      if (msg.type === "migrationOptions") {
        state.migrationOptions = (msg.payload && typeof msg.payload === "object") ? msg.payload : null;
        if (state.activeTab === "storage") render();
        return;
      }
      if (msg.type === "migrationPreview") {
        const preview = (msg.payload && typeof msg.payload === "object") ? msg.payload : {};
        if (!preview.ok) {
          setStatus(String(preview.error || "无法预览迁移包"), "err");
          return;
        }
        (async () => {
          const ok = await confirmMigrationImport(preview);
          if (!ok) {
            setStatus("已取消导入", "");
            return;
          }
          setStatus("正在导入迁移包…", "");
          post({
            type: "invokeAction",
            op: "importMigrationPack",
            payload: { zipPath: String(preview.zipPath || ""), confirmed: true }
          });
        })();
        return;
      }
      if (msg.type === "migrationPackResult") {
        const pl = (msg.payload && typeof msg.payload === "object") ? msg.payload : {};
        const op = String(msg.op || "");
        if (pl.ok) {
          if (op === "export") {
            const zp = String(pl.zipPath || "").trim();
            setStatus(zp ? `迁移包已导出：${zp}` : "迁移包已导出", "ok");
          } else if (op === "import") {
            const note = String(pl.postImportNote || "导入完成。请重新填写 API Key 并建议重启牛马。").trim();
            setStatus(note, "ok");
          } else {
            setStatus("操作成功", "ok");
          }
        } else {
          setStatus(String(pl.error || "迁移包操作失败"), "err");
        }
        return;
      }
      if (msg.type === "actionResult") {
        const op = String(msg.op || "");
        if (op === "syncNiumaChatLlmToStudio" || op === "loadNiumaProjectBrief") return;
        if (op === "getHealthSnapshot" || op === "exportDiagnosticsBundle" || op === "openDebugLogsFolder" || op === "copyRecentTraceLog") return;
        if (op === "getMigrationOptions" || op === "exportMigrationPack" || op === "importMigrationPack") return;
        if (msg.ok) {
          setStatus("操作成功", "ok");
          if (op === "showVk") {
            state.data.vkAvailable = true;
            updateHkVkStatusDom(true);
          }
          if (state.activeTab === "customize") render();
        } else if (msg.error) {
          setStatus(msg.error, "err");
          if (op === "showVk") updateHkVkStatusDom(false);
        }
      }
    }
    loadCustomCategories();
    loadAppearanceActivationMode();
    setInterval(() => {
      if (state.activeTab === "search")
        requestFullTextStatus(false);
    }, 1500);
    // 页面加载时立即从 localStorage 读取主题并应用，消除 initData 到达前的深色闪烁
    (function() {
      try {
        const cached = localStorage.getItem("settings_themeMode");
        if (cached === "light" || cached === "dark") {
          state.data.themeMode = cached;
          applyWebTheme(cached);
        }
      } catch (_) {}
    })();
    document.getElementById("appUpdatePill")?.addEventListener("click", () => post({ type: "openAppRelease" }));

    if (__SETTINGS_CHILD__) {
      const onChildHostMessage = (e) => {
        const d = e.data;
        if (!d) return;
        if (d.channel === "nmer-settings-host") {
          trace("child_host_msg", String(d.type || ""));
          if (d.type === "initSlice") handleHostMessage({ type: "initData", payload: d.payload || {}, navigateToStartTab: !!d.navigateToStartTab });
          else if (d.type === "hostForward") handleHostMessage(d.message || d);
          else if (d.type === "setActiveTab" && d.tab) {
            const nextTab = String(d.tab);
            if (!__SETTINGS_SCOPE__?.tabs?.includes(nextTab)) return;
            if (nextTab !== state.activeTab) {
              leaveActiveTab(state.activeTab);
              try { state.data = readFromUI(); } catch (_) {}
            }
            state.activeTab = nextTab;
            try { sessionStorage.setItem("settings.activeTab", nextTab); } catch (_) {}
            if (nextTab === "storage") state.cacheInfo = null;
            render();
            runLazyInitForTab(nextTab, "host_set_active");
          }
          return;
        }
        if (d.type) handleHostMessage(d);
      };
      window.addEventListener("message", onChildHostMessage);
      if (window.chrome?.webview?.addEventListener)
        window.chrome.webview.addEventListener("message", onChildHostMessage);
      if (__SETTINGS_SCOPE__?.defaultTab) state.activeTab = __SETTINGS_SCOPE__.defaultTab;
      setStatus("等待连接...");
      render();
      setTimeout(() => {
        try {
          trace("post_app_ready");
          window.parent.postMessage({ channel: "nmer-settings-child-lifecycle", stage: "app_ready" }, "*");
          window.parent.postMessage({ channel: "nmer-settings-child-lifecycle", stage: "request_init" }, "*");
        } catch (_) {}
      }, 0);
      const initRetryTimer = setInterval(() => {
        if (initDataReceived) {
          clearInterval(initRetryTimer);
          return;
        }
        try {
          window.parent.postMessage({ channel: "nmer-settings-child-lifecycle", stage: "request_init" }, "*");
          trace("post_request_init");
        } catch (_) {}
      }, 260);
    } else if (window.chrome && window.chrome.webview) {

      window.chrome.webview.addEventListener("message", e => {
        const data = typeof e.data === "string" ? JSON.parse(e.data) : e.data;
        if (__nmDock && typeof __nmDock.onHostMessage === "function") __nmDock.onHostMessage(data);
        handleHostMessage(data);
      });
      if (window.NiumaBottomDock && typeof window.NiumaBottomDock.mount === "function")
        __nmDock = window.NiumaBottomDock.mount({ sceneId: "settings", post: post });
      render();
      post({ type: "ready" });
      setStatus("正在连接...");
      setTimeout(function () {
        if (!initDataReceived) setStatus("连接超时：请重载牛马.ahk 或关闭设置后重开", "err");
      }, 18000);
    } else {
      render();
      setStatus("预览模式");
    }
