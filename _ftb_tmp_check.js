
(function () {
  var LS = 'niuma_chat_drawer_config_v2',
    LEGACY_LS = 'niuma_chat_drawer_config_v1',
    SESSIONS_LS = 'niuma_chat_sessions_v1',
    NIUMA_HISTORY_LS = 'niuma_chat_history_v1',
    NIUMA_HISTORY_API = '/api/niuma/history',
    SP = '你是一个擅长 AHK v2、自动化脚本和桌面工作流的助手。',
    P = {
      openai: { label: 'OpenAI', transport: 'openai', baseUrl: 'https://api.openai.com/v1', model: 'gpt-4.1-mini', models: ['gpt-4.1-mini', 'gpt-4.1', 'gpt-4o-mini', 'gpt-4o'] },
      codex_cli: { label: '命令行（ttyd）', transport: 'cli', baseUrl: 'http://127.0.0.1:7681', model: '', models: [] },
      kimi: { label: 'Kimi', transport: 'openai', baseUrl: 'https://api.moonshot.cn/v1', model: 'moonshot-v1-8k', models: ['moonshot-v1-8k', 'moonshot-v1-32k', 'kimi-k2-0711-preview'] },
      qwen: { label: 'Qwen', transport: 'openai', baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1', model: 'qwen-plus', models: ['qwen-plus', 'qwen-turbo', 'qwen-max', 'qwen3-coder-plus'] },
      deepseek: { label: 'DeepSeek', transport: 'openai', baseUrl: 'https://api.deepseek.com/v1', model: 'deepseek-chat', models: ['deepseek-chat', 'deepseek-reasoner'] },
      claude: { label: 'Claude', transport: 'anthropic', baseUrl: 'https://api.anthropic.com', model: 'claude-3-5-sonnet-latest', models: ['claude-3-5-sonnet-latest', 'claude-3-7-sonnet-latest', 'claude-3-5-haiku-latest'] },
      gemini: { label: 'Gemini', transport: 'gemini', baseUrl: 'https://generativelanguage.googleapis.com/v1beta', model: 'gemini-2.5-flash', models: ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.0-flash'] },
      glm: { label: 'GLM', transport: 'openai', baseUrl: 'https://open.bigmodel.cn/api/paas/v4', model: 'glm-4-plus', models: ['glm-4-plus', 'glm-4-air', 'glm-4-flash'] },
      siliconflow: { label: '硅基流动', transport: 'openai', baseUrl: 'https://api.siliconflow.cn/v1', model: 'Qwen/Qwen2.5-7B-Instruct', models: ['Qwen/Qwen2.5-7B-Instruct', 'deepseek-ai/DeepSeek-V3', 'THUDM/glm-4-9b-chat'] },
      minimax: { label: 'MiniMax', transport: 'openai', baseUrl: 'https://api.minimax.chat/v1', model: 'abab6.5s-chat', models: ['abab6.5s-chat', 'MiniMax-M1', 'MiniMax-Text-01'] },
      zhipu: { label: '智谱', transport: 'openai', baseUrl: 'https://open.bigmodel.cn/api/paas/v4', model: 'glm-4-plus', models: ['glm-4-plus', 'glm-4-air', 'glm-4-flash'] },
      ollama: { label: 'Ollama', transport: 'openai', baseUrl: 'http://127.0.0.1:11434/v1', model: 'llama3.1:8b', models: ['llama3.1:8b', 'qwen2.5:7b', 'deepseek-r1:7b', 'gemma3:4b'] },
      openclaw: { label: 'OpenClaw', transport: 'openclaw', baseUrl: 'http://127.0.0.1:18789', model: 'gateway', models: ['gateway'] }
    },
    PROVIDER_PICK_ORDER = [
      'openai', 'codex_cli', 'kimi', 'qwen', 'deepseek', 'claude', 'gemini', 'glm', 'siliconflow', 'minimax', 'zhipu', 'ollama', 'openclaw'
    ],
    ICON_PRIMARY = 'aiicons/',
    ICON_SECOND = 'lib/images/',
    ICON_FALLBACK = 'lib/images/chat-ai-fallback.svg',
    PROVIDER_ICON_EXTS = ['.png', '.jpg', '.jpeg', '.svg', '.webp'],
    PROVIDER_ICON_BASES = {
      openai: ['ChatGPT', 'chatgpt', 'openai', 'codex', 'Codex'],
      codex_cli: ['terminal', 'cmd', 'cli', 'ttyd', 'console', 'codex', 'Codex', 'openai'],
      kimi: ['kimi', 'Kimi', 'moonshot'],
      qwen: ['qwen', 'Qwen'],
      deepseek: ['DeepSeek', 'deepseek'],
      claude: ['Claude', 'claude'],
      gemini: ['gemini', 'Gemini'],
      glm: ['glm', 'GLM'],
      siliconflow: ['siliconflow', '硅基流动'],
      minimax: ['minimax', 'MiniMax'],
      zhipu: ['zhipu', 'Zhipu'],
      ollama: ['ollama', 'Ollama'],
      openclaw: ['openclaw', 'OpenClaw']
    },
    KEYMETA = {
      openai: { keyLabel: 'OpenAI API Key', keyPlaceholder: 'sk-...', keyHint: '仅保存到「OpenAI」槽位；与 Kimi、DeepSeek 等密钥互不覆盖。' },
      codex_cli: { keyLabel: '无需 API Key', keyPlaceholder: '本模式不使用 API Key', keyHint: '本机 ttyd 本地终端，与上方 OpenAI 云端 API 无关。请配置 ttyd 地址与「终端启动命令」；不需要 Model。' },
      kimi: { keyLabel: 'Kimi（Moonshot）API Key', keyPlaceholder: 'Moonshot 密钥', keyHint: 'Authorization: Bearer；单独保存在「Kimi」槽位。' },
      qwen: { keyLabel: 'DashScope API Key', keyPlaceholder: '阿里云百炼 / DashScope', keyHint: '通义千问兼容 OpenAI 接口；密钥仅存「Qwen」槽位。' },
      deepseek: { keyLabel: 'DeepSeek API Key', keyPlaceholder: 'DeepSeek 密钥', keyHint: '单独保存在「DeepSeek」槽位。' },
      claude: { keyLabel: 'Anthropic API Key', keyPlaceholder: 'sk-ant-...', keyHint: '请求头 x-api-key；单独保存在「Claude」槽位（与 OpenAI 密钥不同）。' },
      gemini: { keyLabel: 'Google AI API Key', keyPlaceholder: 'AIza...', keyHint: '密钥以 query 参数 key= 传递；单独保存在「Gemini」槽位。' },
      glm: { keyLabel: '智谱 BigModel API Key', keyPlaceholder: 'BigModel 密钥', keyHint: '与「智谱」槽位分离保存；均为 OpenAI 兼容但密钥不同。' },
      siliconflow: { keyLabel: '硅基流动 API Key', keyPlaceholder: '硅基流动密钥', keyHint: '单独保存在「硅基流动」槽位。' },
      minimax: { keyLabel: 'MiniMax API Key', keyPlaceholder: 'MiniMax 密钥', keyHint: '单独保存在「MiniMax」槽位。' },
      zhipu: { keyLabel: '智谱 API Key', keyPlaceholder: '智谱开放平台密钥', keyHint: '单独保存在「智谱」槽位（与 GLM BigModel 可填不同密钥）。' },
      ollama: { keyLabel: 'Ollama API Key（可选）', keyPlaceholder: '本地默认可留空', keyHint: '本地 Ollama 默认无需 API Key；如启用鉴权可在此填写。' },
      openclaw: {
        keyLabel: 'Gateway Token',
        keyPlaceholder: '与 openclaw dashboard 中 token 一致',
        keyHint: '也可留空，仅把带 #token= 的完整控制台地址填在 Base URL；走本机 WebSocket，与 OpenAI HTTP 无关。'
      }
    },
    PROMPT_BUILTIN = [
      { id: '_ahk', name: '默认 · AHK / 自动化', text: SP },
      { id: '_empty', name: '空（不设系统提示）', text: '' },
      { id: '_code', name: '代码审查', text: '你是严谨的代码审查助手。指出问题、风险与可改进处，给出具体修改建议，避免空话。' },
      { id: '_zh', name: '简明中文助手', text: '请用简明、准确的中文回答。需要时分条说明；不确定处请标明假设。' },
      { id: '_en', name: 'Concise English', text: 'You are a concise technical assistant. Answer clearly; use bullet points when helpful.' }
    ];

  function $(id) {
    return document.getElementById(id);
  }

  function normalizeProviderId(pid) {
    pid = String(pid || '').trim();
    if (pid === 'llama') return 'ollama';
    if (pid === 'codex') return 'openai';
    return pid;
  }

  var _tpl = $('ftb-toolbar-tpl');
  var _th = _tpl ? _tpl.innerHTML : '';
  var DEFAULT_TOOLBAR_ACTIONS = ['Search', 'Record', 'Prompt', 'NewPrompt', 'Screenshot', 'Settings', 'VirtualKeyboard'];
  function normalizeToolbarActions(actions) {
    var src = Array.isArray(actions) ? actions : DEFAULT_TOOLBAR_ACTIONS;
    var allow = { Search:1, Record:1, Prompt:1, NewPrompt:1, Screenshot:1, Settings:1, VirtualKeyboard:1 };
    var out = [];
    var seen = {};
    src.forEach(function (x) {
      var id = String(x || '').trim();
      if (!id || !allow[id] || seen[id]) return;
      seen[id] = 1;
      out.push(id);
    });
    if (!out.length) out = DEFAULT_TOOLBAR_ACTIONS.slice();
    return out;
  }
  function buildToolbarHtmlByActions(actions) {
    var wrap = document.createElement('div');
    wrap.innerHTML = _th;
    var map = {};
    Array.prototype.slice.call(wrap.querySelectorAll('.tb[data-action]')).forEach(function (el) {
      map[el.getAttribute('data-action') || ''] = el.outerHTML;
    });
    return normalizeToolbarActions(actions).map(function (id) { return map[id] || ''; }).join('');
  }
  function rebuildToolbarButtons(actions) {
    state.toolbarMode = 'legacy';
    state.toolbarActions = normalizeToolbarActions(actions);
    var html = buildToolbarHtmlByActions(state.toolbarActions);
    $('collapsedBtns').innerHTML = html;
    $('drawerBtns').innerHTML = html;
    bindSearchDnD();
    if (state.activeAction) sel(state.activeAction);
  }

  function escAttr(s) {
    return String(s || '')
      .replace(/&/g, '&amp;')
      .replace(/"/g, '&quot;')
      .replace(/</g, '&lt;');
  }

  var TOOLBAR_SVG_PARTS = {
    search:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>',
    record:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 21l3.8-1 10-10a2.3 2.3 0 0 0-3.3-3.3l-10 10L3 21z"/><path d="M12.9 4.9l3.3 3.3"/></svg>',
    prompt:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2"><path d="M12 3c4.97 0 9 3.58 9 8 0 1.8-.67 3.47-1.8 4.82L20 21l-5.02-1.67A10.53 10.53 0 0 1 12 20c-4.97 0-9-3.58-9-8s4.03-9 9-9Z"/></svg>',
    notepad:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3h11a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z"/><path d="M8 7h8"/><path d="M8 11h8"/><path d="M8 15h5"/></svg>',
    screenshot:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2"><path d="M4 7h4l2-2h4l2 2h4v12H4z"/><circle cx="12" cy="13" r="3.5"/></svg>',
    settings:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>',
    keyboard:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2.5" y="5" width="19" height="14" rx="2.5"/><path d="M6 9h1"/><path d="M9 9h1"/><path d="M12 9h1"/><path d="M15 9h1"/><path d="M18 9h1"/><path d="M6 12h1"/><path d="M9 12h1"/><path d="M12 12h1"/><path d="M15 12h1"/><path d="M18 12h1"/><path d="M7 15h10"/></svg>',
    clipboard:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="8" y="2" width="8" height="4" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/></svg>',
    comments:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/></svg>',
    list:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 6h13"/><path d="M8 12h13"/><path d="M8 18h13"/><path d="M3 6h.01"/><path d="M3 12h.01"/><path d="M3 18h.01"/></svg>',
    window:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M9 3v18"/></svg>',
    cloud:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z"/></svg>',
    robot:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="8" width="14" height="10" rx="2"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/><circle cx="9.5" cy="13" r="1" fill="currentColor" stroke="none"/><circle cx="14.5" cy="13" r="1" fill="currentColor" stroke="none"/><path d="M9 18v2"/><path d="M15 18v2"/></svg>',
    bolt:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/></svg>',
    star:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m12 2 2.4 7.4h7.6l-6 4.6 2.3 7-6.3-4.6-6.3 4.6 2.3-7-6-4.6h7.6z"/></svg>',
    circle:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2"><circle cx="12" cy="12" r="9"/></svg>',
  };

  var TOOLBAR_CMD_TO_KEY = {
    sc_activate_search: 'search',
    qa_clipboard: 'clipboard',
    hub_capsule: 'notepad',
    ch_b: 'prompt',
    pqp_capture: 'bolt',
    ch_t: 'screenshot',
    qa_config: 'settings',
    sys_show_vk: 'keyboard',
    ftb_scratchpad: 'notepad',
    ftb_screenshot: 'screenshot',
    ftb_cloud_player: 'cloud',
    ftb_cursor_menu: 'circle',
  };

  var FA_SUFFIX_TO_KEY = {
    'magnifying-glass': 'search',
    clipboard: 'clipboard',
    comments: 'comments',
    lightbulb: 'prompt',
    'note-sticky': 'notepad',
    camera: 'screenshot',
    gear: 'settings',
    keyboard: 'keyboard',
    list: 'list',
    'window-restore': 'window',
    cloud: 'cloud',
    robot: 'robot',
    bolt: 'bolt',
    star: 'star',
    circle: 'circle',
    layer: 'list',
    'layer-group': 'list',
    terminal: 'keyboard',
    sliders: 'settings',
    code: 'bolt',
    'wand-magic-sparkles': 'prompt',
  };

  function extractFaSuffix(iconClass) {
    var parts = String(iconClass || '')
      .trim()
      .split(/\s+/);
    var suf = '';
    for (var i = 0; i < parts.length; i++) {
      var p = parts[i];
      if (p === 'fa-solid' || p === 'fa-brands' || p === 'fa-regular') continue;
      if (p.indexOf('fa-') === 0) suf = p.slice(3);
    }
    return suf || 'circle';
  }

  function toolbarFallbackKey(cmdId, iconClass) {
    var key = TOOLBAR_CMD_TO_KEY[String(cmdId || '').trim()];
    if (!key) {
      var suf = extractFaSuffix(iconClass);
      key = FA_SUFFIX_TO_KEY[suf] || 'bolt';
    }
    return key || 'bolt';
  }

  function normalizeIconPathToFileUrl(path) {
    var p = String(path || '').trim();
    if (!p) return '';
    if (/^(https?:|file:|data:|blob:)/i.test(p)) return p;
    if (/^[a-zA-Z]:[\\/]/.test(p)) return 'file:///' + encodeURI(p.replace(/\\/g, '/'));
    return p;
  }

  function toolbarIconSvgHtml(cmdId, iconClass, iconPath) {
    var fbKey = toolbarFallbackKey(cmdId, iconClass);
    var normalizedPath = normalizeIconPathToFileUrl(iconPath);
    if (String(cmdId || '').trim() === 'ftb_cursor_menu' && normalizedPath) {
      return (
        '<span class="tb-ico"><img class="tb-ico-img" src="' +
        escAttr(normalizedPath) +
        '" alt="" data-fallback-key="' +
        escAttr(fbKey || 'prompt') +
        '"></span>'
      );
    }
    // Default to built-in SVG to avoid intermittent text/icon-font fallbacks.
    var inner = TOOLBAR_SVG_PARTS[fbKey] || TOOLBAR_SVG_PARTS.bolt;
    return '<span class="tb-ico">' + inner + '</span>';
  }

  function attachToolbarIconFallback(root) {
    if (!root) return;
    root.querySelectorAll('img.tb-ico-img[data-fallback-key]').forEach(function (img) {
      if (img.dataset.fbBound === '1') return;
      img.dataset.fbBound = '1';
      var useFallback = function () {
        var wrap = img.parentElement;
        if (!wrap) return;
        var k = String(img.getAttribute('data-fallback-key') || '').trim() || 'bolt';
        wrap.innerHTML = TOOLBAR_SVG_PARTS[k] || TOOLBAR_SVG_PARTS.bolt;
      };
      img.addEventListener('error', useFallback, { once: true });
      if (img.complete && (!img.naturalWidth || !img.naturalHeight)) useFallback();
    });
  }

  function rebuildToolbarCmdButtons(items) {
    state.toolbarMode = 'cmd';
    var arr = Array.isArray(items) ? items : [];
    var html = '';
    arr.forEach(function (it) {
      var cid = String((it && it.cmdId) || '').trim();
      if (!cid) return;
      var nm = escAttr((it && it.name) || cid);
      var ic = String((it && it.iconClass) || 'fa-solid fa-circle');
      var ip = String((it && it.iconPath) || '').trim();
      if (ic.indexOf('fa-') === 0 && ic.indexOf('fa-solid') === -1 && ic.indexOf('fa-brands') === -1 && ic.indexOf('fa-regular') === -1)
        ic = 'fa-solid ' + ic;
      var bucket = 'Search';
      if (cid === 'sc_activate_search') bucket = 'Search';
      else if (cid === 'qa_clipboard' || cid === 'ch_b' || cid === 'pqp_capture' || cid === 'hub_capsule') bucket = 'Prompt';
      var sd = bucket === 'Search' ? ' data-search-drop="1"' : '';
      html +=
        '<button type="button" class="tb" title="' +
        nm +
        '" data-cmd-id="' +
        escAttr(cid) +
        '" data-drop-bucket="' +
        bucket +
        '"' +
        sd +
        '>' +
        toolbarIconSvgHtml(cid, ic, ip) +
        '<span class="dot"></span></button>';
    });
    if (!html)
      html =
        '<span class="hint" style="display:flex;align-items:center;padding:8px 10px;font-size:11px;color:var(--muted)">无工具栏命令（请在 KeyBinder 中配置）</span>';
    $('collapsedBtns').innerHTML = html;
    $('drawerBtns').innerHTML = html;
    attachToolbarIconFallback($('collapsedBtns'));
    attachToolbarIconFallback($('drawerBtns'));
    bindSearchDnD();
    if (state.activeCmdId) sel(state.activeCmdId);
  }

  var stage = $('stage'),
    backdrop = $('backdrop'),
    panel = $('panel'),
    dclose = $('drawer-close'),
    chatSearch = $('chat-search'),
    chatSet = $('chat-settings'),
    chatExportMd = $('chat-export-md'),
    chatExportJson = $('chat-export-json'),
    sessionTabsEl = $('sessionTabs'),
    msgs = $('msgs'),
    empty = $('empty'),
    input = $('input'),
    send = $('send'),
    chatStatus = $('chat-status'),
    settings = $('settings'),
    sbg = document.querySelector('.sbg'),
    sclose = $('settings-close'),
    ssave = $('saveCfg'),
    cfgStatus = $('config-status'),
    ph = $('providerHint'),
    provider = $('provider'),
    apiKey = $('apiKey'),
    baseUrl = $('baseUrl'),
    openclawSessionKey = $('openclawSessionKey'),
    openclawSessionPolicy = $('openclawSessionPolicy'),
    openclawSessionOptions = $('openclawSessionOptions'),
    openclawSessionHint = $('openclawSessionHint'),
    model = $('model'),
    modelPreset = $('modelPreset'),
    systemPrompt = $('systemPrompt'),
    apiKeyLabel = $('apiKeyLabel'),
    apiKeyKeyHint = $('apiKeyKeyHint'),
    promptBuiltin = $('promptBuiltin'),
    promptTplApply = $('promptTplApply'),
    promptImportBtn = $('promptImportBtn'),
    promptImportFile = $('promptImportFile'),
    providerDdBtn = $('providerDdBtn'),
    providerDdMenu = $('providerDdMenu'),
    providerDdIcon = $('providerDdIcon'),
    providerDdLabel = $('providerDdLabel'),
    modelDdBtn = $('modelDdBtn'),
    modelDdMenu = $('modelDdMenu'),
    modelDdIcon = $('modelDdIcon'),
    modelDdLabel = $('modelDdLabel'),
    ttydShellCommand = $('ttydShellCommand'),
    fldModelDdCol = $('fldModelDdCol'),
    fldTtydShellRow = $('fldTtydShellRow'),
    fldBaseUrlRow = $('fldBaseUrlRow'),
    fldOpenClawSessionRow = $('fldOpenClawSessionRow'),
    fldOpenClawPolicyRow = $('fldOpenClawPolicyRow'),
    fldModelRow = $('fldModelRow'),
    resetCfg = $('resetCfg'),
    collapsedRoot = $('collapsedRoot'),
    resizeGrip = $('resizeGrip'),
    newSessionPick = $('newSessionPick'),
    newSessionPickBg = $('newSessionPickBg'),
    newSessionPickClose = $('newSessionPickClose'),
    newSessionGrid = $('newSessionGrid'),
    debugToggle = $('debugToggle'),
    debugPanel = $('debugPanel');

  function tbEls() {
    return document.querySelectorAll('.tb[data-action], .tb[data-cmd-id]');
  }
  function searchEls() {
    return document.querySelectorAll('.tb[data-action=Search], .tb[data-search-drop="1"]');
  }

  function getCachedThemeMode() {
    try {
      var t = String(localStorage.getItem('settings_themeMode') || '').toLowerCase();
      if (t === 'light' || t === 'dark') return t;
    } catch (_) {}
    return 'dark';
  }

  var state = {
    drawer: false,
    compact: false,
    settings: false,
    themeMode: getCachedThemeMode(),
    sendingBySession: {},
    needSetup: false,
    nspick: false,
    activeAction: '',
    apiKeys: {},
    sessions: [],
    activeSessionId: '',
    chatSearchKeyword: '',
    chatSearchCursor: -1,
    toolbarActions: DEFAULT_TOOLBAR_ACTIONS.slice(),
    niumaHistoryStore: { version: 1, sessions: {}, updatedAt: null },
    niumaHistoryLoaded: false,
    dynamicModels: {},
    dynamicModelsFetchedAt: {},
    openclawMetaCache: {},
    openclawSessionRows: [],
    openclawSessionRowsFetchedAt: 0,
    openclawSessionRowsLoading: false
  };
  var toolbarVisibleSynced = false;
  var toolbarRevealTimer = 0;
  var ftbBootStartAt = Date.now();
  var ftbBootHidden = false;
  var DEBUG_HUD = false;
  var debugLines = [];
  var debugSeq = 0;
  var _cliOpenThrottle = 0;
  var _niumaPendingPop = false;
  var _niumaWasCli = false;
  var debugTrace = null;
  var DBG_STAGES = ['prepare', 'connect', 'send', 'ack', 'stream', 'done', 'error'];

  function dbgTs() {
    var d = new Date();
    return d.toTimeString().slice(0, 8) + '.' + String(d.getMilliseconds()).padStart(3, '0');
  }

  function dbgNewTrace(provider, sessionKey) {
    debugTrace = {
      id: 'dbg-' + Date.now() + '-' + Math.random().toString(36).slice(2, 7),
      provider: provider || '',
      sessionKey: sessionKey || '',
      stageMap: { prepare: 'run', connect: 'idle', send: 'idle', ack: 'idle', stream: 'idle', done: 'idle', error: 'idle' },
      events: [],
      lastGoSnapshotAt: ''
    };
    renderDebugTrace();
  }

  function dbgPush(stage, event, data, ok) {
    if (!debugTrace) return;
    var row = { ts: dbgTs(), stage: stage || '', event: event || '', ok: ok !== false, data: data || null };
    debugTrace.events.push(row);
    if (debugTrace.events.length > 100) debugTrace.events = debugTrace.events.slice(-100);
    try {
      post({
        type: 'niuma_debug_event',
        event: { traceId: debugTrace.id, stage: row.stage, event: row.event, ok: row.ok, data: row.data, ts: new Date().toISOString() }
      });
    } catch (_) {}
    renderDebugTrace();
  }

  function dbgMark(stage, status) {
    if (!debugTrace || !stage) return;
    debugTrace.stageMap[stage] = status;
    renderDebugTrace();
  }

  function dbgFail(layer, code, message, hint) {
    dbgMark('error', 'fail');
    dbgPush('error', 'failed', { layer: layer, code: code, message: String(message || ''), hint: String(hint || '') }, false);
  }

  function dbgClass(status) {
    if (status === 'run') return 'dbg-run';
    if (status === 'ok') return 'dbg-ok';
    if (status === 'fail') return 'dbg-fail';
    return 'dbg-idle';
  }

  function renderDebugTrace() {
    var stagesEl = $('debugStages');
    var timelineEl = $('debugTimeline');
    var metaEl = $('debugMeta');
    if (!stagesEl || !timelineEl || !metaEl) return;
    if (!debugTrace) {
      stagesEl.innerHTML = '';
      timelineEl.innerHTML = '';
      metaEl.textContent = '';
      return;
    }
    stagesEl.innerHTML = DBG_STAGES.map(function (s) {
      var st = debugTrace.stageMap[s] || 'idle';
      return '<div class="dbg-stage ' + dbgClass(st) + '"><b>' + esc(s) + '</b><span>' + esc(st) + '</span></div>';
    }).join('');
    timelineEl.innerHTML = debugTrace.events
      .slice(-30)
      .map(function (e) {
        var dataTxt = '';
        if (e.data && typeof e.data === 'object') {
          try {
            dataTxt = ' ' + esc(JSON.stringify(e.data).slice(0, 240));
          } catch (_) {}
        }
        return '<div class="debug-row">[' + esc(e.ts) + '] ' + esc(e.stage || '-') + ' · ' + esc(e.event || '-') + dataTxt + '</div>';
      })
      .join('');
    metaEl.innerHTML =
      '<span>trace: ' +
      esc(debugTrace.id) +
      '</span><span>provider: ' +
      esc(debugTrace.provider || '-') +
      '</span><span>session: ' +
      esc(debugTrace.sessionKey || '-') +
      '</span><span>goSnapshot: ' +
      esc(debugTrace.lastGoSnapshotAt || '-') +
      '</span>';
  }

  function dismissBootSplash(forceNow) {
    if (ftbBootHidden) return;
    var splash = $('ftbBootSplash');
    if (!splash) {
      ftbBootHidden = true;
      return;
    }
    var elapsed = Date.now() - ftbBootStartAt;
    var wait = forceNow ? 0 : Math.max(0, 140 - elapsed);
    function hideNow() {
      if (ftbBootHidden) return;
      ftbBootHidden = true;
      splash.classList.add('hide');
      splash.setAttribute('aria-hidden', 'true');
      setTimeout(function () {
        splash.classList.add('done');
      }, 240);
    }
    if (wait > 0) setTimeout(hideNow, wait);
    else hideNow();
  }

  var ftbBootLogo = $('ftbBootLogo');
  if (ftbBootLogo) {
    ftbBootLogo.addEventListener('load', function () {
      ftbBootLogo.classList.add('ready');
      var fb = $('ftbBootFallback');
      if (fb) fb.hidden = true;
    }, { once: true });
    ftbBootLogo.addEventListener('error', function () {
      ftbBootLogo.style.display = 'none';
      var fb = $('ftbBootFallback');
      if (fb) fb.hidden = false;
    }, { once: true });
  }
  setTimeout(function () { dismissBootSplash(true); }, 2600);

  function dbg(tag, msg, cls) {
    if (!DEBUG_HUD) return;
    var hud = document.getElementById('debugHud');
    if (!hud) return;
    debugSeq += 1;
    var ts = new Date();
    var t = String(ts.getHours()).padStart(2, '0') + ':' + String(ts.getMinutes()).padStart(2, '0') + ':' + String(ts.getSeconds()).padStart(2, '0');
    var text = t + ' ' + String(tag || '') + ' ' + String(msg || '');
    debugLines.push({ text: text, cls: cls || '' });
    if (debugLines.length > 3) debugLines.shift();
    hud.innerHTML = debugLines
      .map(function (it) {
        var c = it.cls ? 'row ' + it.cls : 'row';
        return '<div class="' + c + '">' + esc(it.text) + '</div>';
      })
      .join('');
    hud.scrollTop = hud.scrollHeight;
  }

  (function initDebugHudVisibility() {
    var hud = document.getElementById('debugHud');
    if (hud && !DEBUG_HUD) hud.style.display = 'none';
  })();

  function revealToolbarSync() {
    if (toolbarVisibleSynced) return;
    toolbarVisibleSynced = true;
    document.body.classList.add('ftb-ready');
    dismissBootSplash(false);
  }

  function scheduleToolbarReveal(ms) {
    if (toolbarVisibleSynced) return;
    if (toolbarRevealTimer) clearTimeout(toolbarRevealTimer);
    toolbarRevealTimer = setTimeout(revealToolbarSync, ms);
  }

  function post(m) {
    try {
      if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
        dbg('S', (m && m.type ? m.type : '?'));
        window.chrome.webview.postMessage(JSON.stringify(m));
      }
    } catch (e) {}
  }

  function sel(a) {
    var s = String(a || '');
    state.activeAction = s;
    if (state.toolbarMode === 'cmd') state.activeCmdId = s;
    document.querySelectorAll('.tb').forEach(function (b) {
      var match = b.dataset.action === s || String(b.dataset.cmdId || '') === s;
      b.classList.toggle('selected', match);
    });
  }

  function pulse(v) {
    searchEls().forEach(function (el) {
      el.classList.toggle('pulse', !!v);
    });
  }

  function dragOver(v) {
    searchEls().forEach(function (el) {
      el.classList.toggle('drag-over', !!v);
    });
  }

  function loading(v) {
    searchEls().forEach(function (el) {
      el.classList.toggle('loading', !!v);
    });
  }

  function setCompact(v) {
    state.compact = !!v;
    document.body.classList.toggle('ftb-compact', state.compact);
  }

  function scrollMsgsToLatest() {
    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        if (!msgs) return;
        msgs.scrollTop = msgs.scrollHeight;
      });
    });
  }

  function scale(v) {
    v = Number(v);
    if (!isFinite(v) || v <= 0) v = 1;
    document.documentElement.style.setProperty('--ui', String(v));
  }

  function drawerResizeBoundsPx() {
    var u = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--ui').trim());
    if (!isFinite(u) || u <= 0) u = 1;
    return { min: Math.max(1, Math.round(380 * u)), max: Math.max(1, Math.round(1200 * u)) };
  }

  function applyTheme(mode) {
    var tm = String(mode || '').toLowerCase() === 'light' ? 'light' : 'dark';
    state.themeMode = tm;
    document.body.setAttribute('data-theme', tm);
    try {
      var s = activeSession();
      if (isCliSession(s) && document.body.classList.contains('cli-mode')) {
        var u = cliUrlForSession(s);
        if (u) applyCliFrameUrl(u);
      }
    } catch (e) {}
  }

  function setDrawer(v) {
    state.drawer = !!v;
    document.body.classList.toggle('drawer-open', state.drawer);
    stage.setAttribute('aria-hidden', state.drawer ? 'false' : 'true');
    panel.setAttribute('aria-hidden', state.drawer ? 'false' : 'true');
    post({ type: 'drawer_state', open: state.drawer });
    if (!state.drawer) {
      setSettings(false);
      setNspick(false);
      return;
    }
    scrollMsgsToLatest();
    if (state.needSetup) {
      var sd = activeSession();
      var pp = sd && P[normalizeProviderId(sd.provider)];
      if (!pp || pp.transport !== 'cli') setSettings(true);
    }
  }

  function setNspick(v) {
    state.nspick = !!v;
    document.body.classList.toggle('nspick-open', state.nspick);
    if (newSessionPick) newSessionPick.setAttribute('aria-hidden', state.nspick ? 'false' : 'true');
  }

  function setSettings(v) {
    state.settings = !!v;
    if (state.settings) setNspick(false);
    document.body.classList.toggle('settings-open', state.settings);
    settings.setAttribute('aria-hidden', state.settings ? 'false' : 'true');
    if (state.settings) {
      syncProviderDdUi();
      syncModelDdUi();
      updateProviderFormLayout(normalizeProviderId(provider.value));
    }
  }

  function esc(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function ahk(code) {
    var h = esc(code);
    h = h.replace(/(^|\n)(\s*;.*)/g, function (m, p1, p2) {
      return p1 + '<span class="hl-comment">' + p2 + '</span>';
    });
    h = h.replace(/("(?:[^"\\]|\\.)*")/g, '<span class="hl-string">$1</span>');
    h = h.replace(/('(?:[^'\\]|\\.)*')/g, '<span class="hl-string">$1</span>');
    h = h.replace(/\b(\d+(?:\.\d+)?)\b/g, '<span class="hl-number">$1</span>');
    h = h.replace(/\b(global|local|static|if|else|try|catch|return|switch|case|default|for|while|loop|break|continue|class|extends|throw)\b/g, '<span class="hl-keyword">$1</span>');
    h = h.replace(/\b(Map|Array|Gui|Error|Integer|Float|String|Trim|Format|RegExMatch|SetTimer|Send|Sleep|FileRead|FileAppend|IniRead|IniWrite)\b/g, '<span class="hl-builtins">$1</span>');
    h = h.replace(/\b([A-Za-z_][A-Za-z0-9_]*)\b(?=\s*:=)/g, '<span class="hl-var">$1</span>');
    return h;
  }

  /** API 常返回 <br> / 已转义的换行，先换成 \n 再走 Markdown，避免屏上显示字面量 <br> */
  function preMarkdownForChat(s) {
    s = String(s || '').replace(/\r\n/g, '\n');
    s = s.replace(/<br\s*\/?>/gi, '\n');
    s = s.replace(/&lt;\s*br\s*\/?\s*&gt;/gi, '\n');
    return s;
  }

  function inline(t) {
    var h = esc(t);
    h = h.replace(/`([^`]+)`/g, '<code class="inline">$1</code>')
      .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
      .replace(/\*([^*]+)\*/g, '<em>$1</em>')
      .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noreferrer">$1</a>');
    return h;
  }

  function md(src) {
    src = String(src || '').replace(/\r\n/g, '\n');
    var out = [],
      rx = /```(\w+)?\n([\s\S]*?)```/g,
      last = 0,
      m;
    while ((m = rx.exec(src))) {
      if (m.index > last) out.push({ t: 'text', c: src.slice(last, m.index) });
      out.push({ t: 'code', l: (m[1] || '').toLowerCase(), c: m[2] });
      last = rx.lastIndex;
    }
    if (last < src.length) out.push({ t: 'text', c: src.slice(last) });
    return out
      .map(function (b) {
        if (b.t === 'code') {
          var hi = b.l === 'ahk' || b.l === 'autohotkey' || b.l === 'autohotkeyv2' ? ahk(b.c) : esc(b.c);
          return '<pre><code>' + hi + '</code></pre>';
        }
        return b.c
          .split(/\n{2,}/)
          .map(function (chunk) {
            var t = chunk.trim();
            if (!t) return '';
            if (/^\s*>\s?/.test(t)) return '<blockquote>' + inline(t.replace(/^\s*>\s?/gm, '').replace(/\n/g, '<br>')) + '</blockquote>';
            if (/^\s*[-*]\s+/m.test(t)) {
              var items = t
                .split('\n')
                .map(function (line) {
                  return line.replace(/^\s*[-*]\s+/, '').trim();
                })
                .filter(Boolean);
              return '<ul>' + items.map(function (i) { return '<li>' + inline(i) + '</li>'; }).join('') + '</ul>';
            }
            if (/^#{1,3}\s+/.test(t)) {
              var lv = t.match(/^#+/)[0].length,
                cl = t.replace(/^#{1,3}\s+/, '');
              return '<h' + lv + '>' + inline(cl) + '</h' + lv + '>';
            }
            return '<p>' + inline(t.replace(/\n/g, '<br>')) + '</p>';
          })
          .join('');
      })
      .join('');
  }

  function genId() {
    return 's' + Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
  }

  function activeSession() {
    var list = state.sessions,
      id = state.activeSessionId;
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === id) return list[i];
    }
    return list[0] || null;
  }

  function sessionById(id) {
    var list = state.sessions || [];
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].id === id) return list[i];
    }
    return null;
  }

  function providerTransport(pid) {
    pid = normalizeProviderId(pid);
    var p = pid && P[pid] ? P[pid] : P.openai;
    return String(p.transport || 'openai');
  }

  function isCliSession(s) {
    if (!s) return false;
    return providerTransport(s.provider) === 'cli';
  }

  function cliUrlForSession(s) {
    if (!s) return '';
    var pid = normalizeProviderId(s.provider);
    var p = pid && P[pid] ? P[pid] : null;
    if (!p) return '';
    // CLI 视图以 baseUrl 作为 ttyd 页面地址
    var u = String((s.baseUrl || '').trim() || (p.baseUrl || '')).trim();
    // 历史配置里若是 localhost，则归一到 127.0.0.1，避免 localhost->::1 导致拒绝连接
    if (u === 'http://localhost:7681' || u === 'http://localhost:7681/')
      u = 'http://127.0.0.1:7681/';
    return cliUrlWithTheme(u);
  }

  function cliThemePayload() {
    var light = String(state.themeMode || '').toLowerCase() === 'light';
    return light
      ? {
          scrollbarSliderBackground: 'rgba(230,126,34,0.36)',
          scrollbarSliderHoverBackground: 'rgba(211,84,0,0.56)',
          scrollbarSliderActiveBackground: 'rgba(211,84,0,0.72)'
        }
      : {
          scrollbarSliderBackground: 'rgba(255,120,48,0.4)',
          scrollbarSliderHoverBackground: 'rgba(255,132,64,0.6)',
          scrollbarSliderActiveBackground: 'rgba(255,150,80,0.76)'
        };
  }

  function cliUrlWithTheme(rawUrl) {
    var u = String(rawUrl || '').trim();
    if (!u) return '';
    try {
      var obj = new URL(u, window.location.href);
      obj.searchParams.set('theme', JSON.stringify(cliThemePayload()));
      return obj.toString();
    } catch (e) {
      return u;
    }
  }

  function applyCliFrameUrl(u) {
    u = String(u || '').trim();
    if (!u) return;
    var fr = $('cliFrame');
    if (!fr) return;
    fr.dataset.src = u;
    var cur = String(fr.src || '').trim();
    if (cur === u) {
      try {
        fr.src = 'about:blank';
      } catch (e) {}
    }
    fr.src = u;
  }

  function cliFrameUrlLooksLive() {
    var fr = $('cliFrame');
    if (!fr) return false;
    var u = String(fr.src || '').trim();
    return !!u && u !== 'about:blank';
  }

  /** 请求宿主拉起 ttyd；force 时跳过节流（按钮/发消息时） */
  function throttledNiumaCliOpen(force) {
    var now = Date.now();
    if (!force && now - _cliOpenThrottle < 700) return;
    _cliOpenThrottle = now;
    try {
      var s = activeSession();
      if (!s) return;
      post({ type: 'niuma_cli_open', engine: s.provider });
    } catch (e) {}
  }

  function syncChatViewMode() {
    var s = activeSession();
    var on = isCliSession(s);
    var fr = $('cliFrame');
    document.body.classList.toggle('cli-mode', !!on);
    try {
      var titleEl = $('cliTitle');
      if (titleEl) {
        var pl = (s && P[s.provider] ? P[s.provider].label : (s && s.provider ? s.provider : 'CLI'));
        titleEl.textContent = pl + ' · ttyd';
      }
    } catch (e) {}
    if (!on) {
      _niumaPendingPop = false;
      if (_niumaWasCli && fr) {
        try {
          fr.src = 'about:blank';
          if (fr.dataset) fr.dataset.src = '';
        } catch (e) {}
      }
      _niumaWasCli = false;
      return;
    }
    var prevWasCli = _niumaWasCli;
    _niumaWasCli = true;
    var directUrl = cliUrlForSession(s);
    var needSpawn = !prevWasCli || !cliFrameUrlLooksLive();
    if (!needSpawn && directUrl) applyCliFrameUrl(directUrl);
    if (needSpawn) throttledNiumaCliOpen(false);
    cstatForSession(
      s.id,
      needSpawn ? '正在连接本机终端（ttyd）…' : '本机终端已加载，可在标签间切换。'
    );
  }

  function normalizeRole(role) {
    var r = String(role || '').toLowerCase().trim();
    if (!r) return '';
    if (
      r === 'assistant' ||
      r === 'ai' ||
      r === 'bot' ||
      r === 'model' ||
      r === 'agent' ||
      r === 'openclaw' ||
      r === 'assistant_message'
    )
      return 'assistant';
    if (
      r === 'human' ||
      r === 'user' ||
      r === 'customer' ||
      r === 'client' ||
      r === 'operator' ||
      r === 'user_message'
    )
      return 'user';
    return '';
  }

  function ocRoleFromHistoryItem(m) {
    if (!m || typeof m !== 'object') return '';
    if (m.assistant === true || m.isAssistant === true) return 'assistant';
    if (m.user === true || m.isUser === true) return 'user';
    var cands = [
      m.role,
      m.type,
      m.actor,
      m.author,
      m.sender,
      m.from,
      m.kind,
      m.source,
      m.channel,
      m.message && m.message.role,
      m.payload && m.payload.role,
      m.data && m.data.role,
      m.result && m.result.role,
      m.response && m.response.role,
      m.assistantMessage && m.assistantMessage.role,
      m.assistant_message && m.assistant_message.role,
      m.userMessage && m.userMessage.role,
      m.user_message && m.user_message.role
    ];
    for (var i = 0; i < cands.length; i++) {
      var rr = normalizeRole(cands[i]);
      if (rr) return rr;
    }
    return '';
  }

  function ensureIsoTime(ts) {
    if (!ts) return new Date().toISOString();
    var t = new Date(ts);
    if (isNaN(t.getTime())) return new Date().toISOString();
    return t.toISOString();
  }

  /** 从 Gateway / 持久化 JSON 中取出可展示正文（含 parts[]、嵌套 content） */
  function ocExtractMessageContentForHistory(m) {
    if (!m || typeof m !== 'object') return '';
    if (Array.isArray(m.content)) {
      var textParts = [];
      for (var ci = 0; ci < m.content.length; ci++) {
        var cp = m.content[ci];
        if (cp && cp.type === 'text' && typeof cp.text === 'string' && cp.text.trim()) {
          textParts.push(cp.text.trim());
        }
      }
      if (textParts.length) return textParts.join('\n').trim();
    }
    /* 勿在 content==="" 时提前返回：网关常把正文放在 text / parts，content 仅占位空串 */
    var strFields = [
      'content',
      'text',
      'message',
      'body',
      'input',
      'output',
      'prompt',
      'value',
      'answer',
      'response',
      'output_text',
      'outputText',
      'assistantText',
      'assistant_text',
      'finalText',
      'final_text',
      'final'
    ];
    for (var si = 0; si < strFields.length; si++) {
      var sf = m[strFields[si]];
      if (typeof sf === 'string' && sf.trim()) return sf.trim();
    }
    var acc = [];
    if (m.content != null && typeof m.content !== 'string') ocCollectTextDeep(m.content, acc);
    if (!acc.length && m.message != null && typeof m.message !== 'string') ocCollectTextDeep(m.message, acc);
    if (!acc.length && m.payload != null && typeof m.payload !== 'string') ocCollectTextDeep(m.payload, acc);
    if (!acc.length && m.data != null && typeof m.data !== 'string') ocCollectTextDeep(m.data, acc);
    if (!acc.length && m.result != null && typeof m.result !== 'string') ocCollectTextDeep(m.result, acc);
    if (!acc.length && m.response != null && typeof m.response !== 'string') ocCollectTextDeep(m.response, acc);
    if (!acc.length && m.output != null && typeof m.output !== 'string') ocCollectTextDeep(m.output, acc);
    if (!acc.length && m.answer != null && typeof m.answer !== 'string') ocCollectTextDeep(m.answer, acc);
    if (!acc.length && m.assistantMessage != null && typeof m.assistantMessage !== 'string') ocCollectTextDeep(m.assistantMessage, acc);
    if (!acc.length && m.assistant_message != null && typeof m.assistant_message !== 'string') ocCollectTextDeep(m.assistant_message, acc);
    if (!acc.length && Array.isArray(m.parts)) {
      for (var pi = 0; pi < m.parts.length; pi++) {
        var p = m.parts[pi];
        if (p && typeof p === 'object') ocCollectTextDeep(p, acc);
      }
    }
    if (acc.length) return acc.join('\n').trim();
    return '';
  }

  function normalizeHistoryItem(m) {
    if (!m || typeof m !== 'object') return null;
    var role = ocRoleFromHistoryItem(m);
    if (!role) return null;
    var content = ocExtractMessageContentForHistory(m);
    if (!content) return null;
    return { role: role, content: content, ts: ensureIsoTime(m.ts || m.timestamp || m.createdAt || m.updatedAt) };
  }

  function historyItemKey(m) {
    var sec = '';
    try {
      sec = Math.floor(new Date(m.ts || 0).getTime() / 1000) || '';
    } catch (e) {}
    return [m.role || '', m.content || '', sec].join('|');
  }

  function mergeHistoryList(base, extra) {
    var out = [],
      seen = {};
    (Array.isArray(base) ? base : []).forEach(function (m) {
      var n = normalizeHistoryItem(m);
      if (!n) return;
      var k = historyItemKey(n);
      if (seen[k]) return;
      seen[k] = 1;
      out.push(n);
    });
    (Array.isArray(extra) ? extra : []).forEach(function (m) {
      var n = normalizeHistoryItem(m);
      if (!n) return;
      var k = historyItemKey(n);
      if (seen[k]) return;
      seen[k] = 1;
      out.push(n);
    });
    return out;
  }

  function buildOpenClawSessionKey(seed) {
    var raw = String(seed || '').trim();
    if (!raw) raw = genId();
    raw = raw.replace(/[^a-zA-Z0-9_-]+/g, '-');
    raw = raw.replace(/-+/g, '-').replace(/^-|-$/g, '');
    if (!raw) raw = 'session';
    return 'niuma-' + raw;
  }

  function normalizeOpenClawSessionKey(key) {
    var k = String(key || '').trim();
    if (!k) return 'agent:main:main';
    if (k === 'main') return 'agent:main:main';
    if (/^agent:[^:]+:.+$/i.test(k)) return k;
    return 'agent:main:' + k;
  }

  function openClawSessionPolicyValue() {
    var v = openclawSessionPolicy ? String(openclawSessionPolicy.value || '').trim() : '';
    return v === 'follow' ? 'follow' : 'stable';
  }

  function resolveOpenClawSessionKey(preferred, fallback) {
    var policy = openClawSessionPolicyValue();
    if (policy === 'stable') return 'agent:main:main';
    var p = String(preferred || '').trim();
    if (p) return normalizeOpenClawSessionKey(p);
    var fb = String(fallback || '').trim();
    if (fb) return normalizeOpenClawSessionKey(fb);
    return 'agent:main:main';
  }

  function getOpenClawSessionKey(s) {
    if (!s) return resolveOpenClawSessionKey('', '');
    var own = resolveOpenClawSessionKey(String(s.gatewaySessionKey || '').trim(), '');
    if (!own) {
      own = resolveOpenClawSessionKey('', '');
      s.gatewaySessionKey = own;
    }
    return own;
  }

  function historyStoreKeyForSession(s) {
    if (!s) return '';
    if (s.provider === 'openclaw') return 'openclaw:' + getOpenClawSessionKey(s);
    return 'local:' + String(s.id || '');
  }

  function loadNiumaHistoryStoreFromLocal() {
    var raw = null;
    try {
      raw = localStorage.getItem(NIUMA_HISTORY_LS);
    } catch (e) {}
    if (!raw) return { version: 1, sessions: {}, updatedAt: null };
    try {
      var obj = JSON.parse(raw);
      if (!obj || typeof obj !== 'object') throw new Error('invalid');
      if (!obj.sessions || typeof obj.sessions !== 'object') obj.sessions = {};
      return obj;
    } catch (e2) {
      return { version: 1, sessions: {}, updatedAt: null };
    }
  }

  function saveNiumaHistoryStoreToLocal() {
    try {
      localStorage.setItem(NIUMA_HISTORY_LS, JSON.stringify(state.niumaHistoryStore || { version: 1, sessions: {}, updatedAt: null }));
    } catch (e) {}
  }

  function pushSessionHistoryToStore(s) {
    if (!s) return;
    if (!state.niumaHistoryStore || typeof state.niumaHistoryStore !== 'object') state.niumaHistoryStore = { version: 1, sessions: {}, updatedAt: null };
    if (!state.niumaHistoryStore.sessions || typeof state.niumaHistoryStore.sessions !== 'object') state.niumaHistoryStore.sessions = {};
    var key = historyStoreKeyForSession(s);
    if (!key) return;
    var merged = mergeHistoryList(state.niumaHistoryStore.sessions[key] || [], s.history || []);
    state.niumaHistoryStore.sessions[key] = merged.slice(-400);
    state.niumaHistoryStore.updatedAt = new Date().toISOString();
    saveNiumaHistoryStoreToLocal();
    fetch(NIUMA_HISTORY_API, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ data: state.niumaHistoryStore })
    }).catch(function () {});
  }

  function pullStoreHistoryToSession(s) {
    if (!s) return;
    if (!state.niumaHistoryStore || !state.niumaHistoryStore.sessions) return;
    var key = historyStoreKeyForSession(s);
    if (!key) return;
    var arr = state.niumaHistoryStore.sessions[key];
    if ((!Array.isArray(arr) || !arr.length) && s.provider === 'openclaw') {
      var sk = getOpenClawSessionKey(s);
      var collected = [];
      state.sessions.forEach(function (x) {
        if (!x || x.id === s.id || x.provider !== 'openclaw') return;
        if (getOpenClawSessionKey(x) !== sk) return;
        collected = mergeHistoryList(collected, x.history || []);
      });
      arr = collected;
    }
    if (!Array.isArray(arr) || !arr.length) return;
    s.history = mergeHistoryList(s.history || [], arr).slice(-400);
  }

  function loadNiumaHistoryStore() {
    state.niumaHistoryStore = loadNiumaHistoryStoreFromLocal();
    state.niumaHistoryLoaded = true;
    fetch(NIUMA_HISTORY_API, { method: 'GET', cache: 'no-store' })
      .then(function (r) {
        if (!r.ok) throw new Error('history api');
        return r.json();
      })
      .then(function (body) {
        var data = body && body.data ? body.data : body;
        if (!data || typeof data !== 'object' || !data.sessions || typeof data.sessions !== 'object') return;
        if (!state.niumaHistoryStore.sessions || typeof state.niumaHistoryStore.sessions !== 'object') state.niumaHistoryStore.sessions = {};
        Object.keys(data.sessions).forEach(function (k) {
          state.niumaHistoryStore.sessions[k] = mergeHistoryList(state.niumaHistoryStore.sessions[k] || [], data.sessions[k] || []).slice(-400);
        });
        state.niumaHistoryStore.updatedAt = data.updatedAt || state.niumaHistoryStore.updatedAt || new Date().toISOString();
        saveNiumaHistoryStoreToLocal();
      })
      .catch(function () {});
  }

  function persistSessions() {
    try {
      localStorage.setItem(
        SESSIONS_LS,
        JSON.stringify({ v: 1, activeSessionId: state.activeSessionId, sessions: state.sessions })
      );
    } catch (e) {
      cstat('本地存储可能已满，请导出后删除部分对话标签。', 'error');
    }
  }

  function loadSessions() {
    var raw = null;
    try {
      raw = localStorage.getItem(SESSIONS_LS);
    } catch (e) {}
    state.sessions = [];
    state.activeSessionId = '';
    if (!raw) return;
    var data;
    try {
      data = JSON.parse(raw);
    } catch (e) {
      return;
    }
    if (!data || !Array.isArray(data.sessions)) return;
    state.sessions = data.sessions.map(function (s) {
      var sp = normalizeProviderId(s.provider);
      var pid = sp && P[sp] ? sp : 'openai';
      var gk = String(s.gatewaySessionKey || '').trim();
      var mModel = s.model || '';
      if (pid === 'codex_cli') mModel = '';
      return {
        id: s.id || genId(),
        provider: pid,
        model: mModel,
        baseUrl: s.baseUrl || '',
        gatewaySessionKey: pid === 'openclaw' ? normalizeOpenClawSessionKey(gk || 'agent:main:main') : '',
        openclawMeta: pid === 'openclaw' && s.openclawMeta && typeof s.openclawMeta === 'object' ? s.openclawMeta : null,
        history: Array.isArray(s.history)
          ? s.history.map(function (m) {
              var n = normalizeHistoryItem(m);
              if (!n) return null;
              return {
                role: n.role,
                content: n.content,
                ts: n.ts
              };
            }).filter(Boolean)
          : []
      };
    });
    state.activeSessionId = data.activeSessionId || (state.sessions[0] && state.sessions[0].id) || '';
  }

  function createSessionFromForm() {
    var pv = normalizeProviderId(provider.value);
    var pid = pv && P[pv] ? pv : 'openai';
    var p = P[pid] || P.openai;
    var sid = genId();
    var wantedOpenClawKey = openclawSessionKey ? String(openclawSessionKey.value || '').trim() : '';
    var hintedOpenClawKey = openClawSessionKeyHintFromBaseUrl(baseUrl.value.trim());
    return {
      id: sid,
      provider: pid,
      model: p.transport === 'cli' ? '' : model.value.trim() || p.model,
      baseUrl: baseUrl.value.trim(),
      gatewaySessionKey: pid === 'openclaw' ? resolveOpenClawSessionKey(wantedOpenClawKey, hintedOpenClawKey || 'agent:main:main') : '',
      history: []
    };
  }

  function ensureSessions() {
    if (state.sessions.length === 0) {
      var s = createSessionFromForm();
      state.sessions.push(s);
      state.activeSessionId = s.id;
      persistSessions();
    } else if (!state.activeSessionId || !activeSession()) {
      state.activeSessionId = state.sessions[0].id;
    }
  }

  function syncFormFromSession(s) {
    if (!s) return;
    var sp = normalizeProviderId(s.provider);
    var pid = sp && P[sp] ? sp : 'openai';
    provider.value = pid;
    var p = P[pid] || P.openai;
    if (p.transport === 'cli') {
      fillModels(pid, '');
      model.value = '';
    } else {
      fillModels(pid, s.model);
      model.value = pid === 'openclaw' ? 'gateway' : s.model || p.model;
    }
    baseUrl.value = (s.baseUrl || '').trim() || p.baseUrl;
    if (openclawSessionKey) openclawSessionKey.value = pid === 'openclaw' ? getOpenClawSessionKey(s) : '';
    hint(pid);
    apiKey.value = (state.apiKeys && state.apiKeys[pid]) || '';
    refreshApiKeyField(pid);
    provider.dataset.prevProv = pid;
    syncProviderDdUi();
    updateProviderFormLayout(pid);
  }

  function syncSessionFromForm(s) {
    if (!s) return;
    var pv = normalizeProviderId(provider.value);
    var pid = pv && P[pv] ? pv : 'openai';
    var p = P[pid] || P.openai;
    s.provider = pid;
    s.model = p.transport === 'cli' ? '' : pid === 'openclaw' ? 'gateway' : model.value.trim() || p.model;
    s.baseUrl = baseUrl.value.trim();
    if (pid !== 'openclaw') s.gatewaySessionKey = '';
    else {
      var wantedRaw = openclawSessionKey ? String(openclawSessionKey.value || '').trim() : '';
      var wanted = normalizeOpenClawSessionKey(wantedRaw);
      var hinted = openClawSessionKeyHintFromBaseUrl(s.baseUrl);
      // Manual entry must win; especially "main" => "agent:main:main".
      if (wantedRaw) s.gatewaySessionKey = resolveOpenClawSessionKey(wanted, hinted || getOpenClawSessionKey(s));
      else s.gatewaySessionKey = resolveOpenClawSessionKey('', hinted || getOpenClawSessionKey(s));
    }
  }

  function providerIconUrlList(pid) {
    pid = pid && P[pid] ? pid : 'openai';
    var bases = PROVIDER_ICON_BASES[pid];
    if (!bases || !bases.length) bases = [pid];
    var list = [];
    bases.forEach(function (base) {
      PROVIDER_ICON_EXTS.forEach(function (ext) {
        list.push(ICON_SECOND + base + ext);
      });
    });
    list.push(ICON_PRIMARY + pid + '.svg');
    list.push(ICON_SECOND + pid + '.svg');
    list.push(ICON_FALLBACK);
    var seen = {},
      out = [];
    list.forEach(function (u) {
      if (!seen[u]) {
        seen[u] = 1;
        out.push(u);
      }
    });
    return out;
  }

  function bindProviderIconImg(img, pid, extraClass) {
    img.alt = '';
    img.loading = 'lazy';
    img.className = 'stab-ico-img' + (extraClass ? ' ' + extraClass : '');
    var urls = providerIconUrlList(pid);
    var idx = 0;
    img.onerror = function () {
      idx += 1;
      if (idx < urls.length) {
        this.src = urls[idx];
      } else {
        this.onerror = null;
      }
    };
    img.removeAttribute('src');
    img.src = urls[0];
  }

  function refreshApiKeyField(pid) {
    var km = KEYMETA[pid] || {},
      lab = apiKeyLabel,
      kh = apiKeyKeyHint;
    if (lab) lab.textContent = km.keyLabel || 'API Key';
    apiKey.placeholder = km.keyPlaceholder || '填写密钥';
    try {
      var p = P[pid] || {};
      var isCli = p && p.transport === 'cli';
      apiKey.type = pid === 'openclaw' ? 'text' : 'password';
      apiKey.spellcheck = false;
      apiKey.disabled = !!isCli;
      apiKey.setAttribute('aria-disabled', isCli ? 'true' : 'false');
      apiKey.style.opacity = isCli ? '0.6' : '';
    } catch (e) {}
    if (kh) {
      if (km.keyHint) {
        kh.textContent = km.keyHint;
        kh.style.display = '';
      } else {
        kh.textContent = '';
        kh.style.display = 'none';
      }
    }
  }

  function updateProviderFormLayout(pid) {
    pid = normalizeProviderId(pid);
    if (!(pid && P[pid])) pid = 'openai';
    var p = P[pid] || P.openai;
    var isCli = p.transport === 'cli';
    var isOpenClaw = pid === 'openclaw';
    if (fldModelDdCol) fldModelDdCol.style.display = isCli ? 'none' : '';
    if (fldModelRow) fldModelRow.style.display = isCli || isOpenClaw ? 'none' : '';
    if (fldTtydShellRow) fldTtydShellRow.style.display = isCli ? '' : 'none';
    if (fldOpenClawSessionRow) fldOpenClawSessionRow.style.display = !isCli && isOpenClaw ? '' : 'none';
    if (fldOpenClawPolicyRow) fldOpenClawPolicyRow.style.display = !isCli && isOpenClaw ? '' : 'none';
    if (!isCli && isOpenClaw) refreshOpenClawSessionRows(false);
    if (fldBaseUrlRow) {
      var bl = fldBaseUrlRow.querySelector('label[for="baseUrl"]');
      if (bl) bl.textContent = isCli ? 'ttyd 地址（Base URL）' : 'Base URL';
    }
  }

  function migrateApiKeysFromStorage(d) {
    state.apiKeys = {};
    if (d.apiKeys && typeof d.apiKeys === 'object') {
      var oa = d.apiKeys.openai;
      var cx = d.apiKeys.codex;
      Object.keys(d.apiKeys).forEach(function (k) {
        if (k === 'openai' || k === 'codex') return;
        var nk = normalizeProviderId(k);
        if (d.apiKeys[k] != null) state.apiKeys[nk] = String(d.apiKeys[k]);
      });
      if (oa != null && String(oa).trim() !== '') state.apiKeys.openai = String(oa);
      else if (cx != null && String(cx).trim() !== '') state.apiKeys.openai = String(cx);
    }
    if (!Object.keys(state.apiKeys).length && d.apiKey) {
      var dp = normalizeProviderId(d.provider);
      var lk = dp && P[dp] ? dp : 'openai';
      state.apiKeys[lk] = String(d.apiKey);
    }
  }

  function fillPromptBuiltinSelect() {
    if (!promptBuiltin) return;
    var opts = '<option value="">— 内置模版 —</option>';
    PROMPT_BUILTIN.forEach(function (t) {
      opts += '<option value="' + esc(t.id) + '">' + esc(t.name) + '</option>';
    });
    promptBuiltin.innerHTML = opts;
    promptBuiltin.value = '';
  }

  function applySelectedPromptBuiltin() {
    if (!promptBuiltin || !promptBuiltin.value) {
      sstat('请先在列表中选择一个内置模版。', 'error');
      return;
    }
    var id = promptBuiltin.value,
      found = null;
    for (var i = 0; i < PROMPT_BUILTIN.length; i++) {
      if (PROMPT_BUILTIN[i].id === id) {
        found = PROMPT_BUILTIN[i];
        break;
      }
    }
    if (!found) return;
    systemPrompt.value = found.text;
    saveCfg(false);
    sstat('已应用模版：' + found.name, 'success');
  }

  function shortModel(m) {
    m = String(m || '').trim();
    if (!m) return '…';
    var tail = m.replace(/^.*\//, '');
    if (tail.length > 9) return tail.slice(0, 7) + '…';
    return tail;
  }

  function tabTitleForSession(s) {
    if (!s) return '';
    var sp = normalizeProviderId(s.provider);
    var pl = (P[sp] || {}).label || s.provider || '';
    if (isCliSession(s)) return pl + ' · CLI';
    return pl + ' · ' + shortModel(s.model);
  }

  function renderSessionTabs() {
    if (!sessionTabsEl) return;
    sessionTabsEl.innerHTML = '';
    state.sessions.forEach(function (s) {
      var wrap = document.createElement('div');
      wrap.className = 'stab' + (s.id === state.activeSessionId ? ' active' : '');
      wrap.setAttribute('role', 'tab');
      wrap.dataset.sessionId = s.id;
      wrap.setAttribute('title', tabTitleForSession(s));
      var ico = document.createElement('span');
      ico.className = 'stab-ico';
      ico.setAttribute('aria-hidden', 'true');
      var im = document.createElement('img');
      bindProviderIconImg(im, normalizeProviderId(s.provider));
      ico.appendChild(im);
      var t = document.createElement('span');
      t.className = 'stab-t';
      t.textContent = isCliSession(s) ? 'CLI' : shortModel(s.model);
      var x = document.createElement('button');
      x.type = 'button';
      x.className = 'stab-x';
      x.setAttribute('aria-label', '关闭标签');
      x.textContent = '×';
      x.setAttribute('data-close-session', s.id);
      wrap.appendChild(ico);
      wrap.appendChild(t);
      wrap.appendChild(x);
      sessionTabsEl.appendChild(wrap);
    });
    var addBtn = document.createElement('button');
    addBtn.type = 'button';
    addBtn.className = 'stab-add';
    addBtn.id = 'sessionTabAdd';
    addBtn.textContent = '+';
    addBtn.setAttribute('title', '选择 AI 新建对话');
    addBtn.setAttribute('aria-label', '选择 AI 新建对话');
    sessionTabsEl.appendChild(addBtn);
    refreshSendUi();
    syncChatViewMode();
  }

  function emptyState() {
    var s = activeSession();
    if (!s || s.history.length) {
      if (empty) empty.style.display = 'none';
      return;
    }
    if (isCliSession(s)) {
      empty.textContent = '本机命令行：输入内容后点发送，将拉起或聚焦 ttyd 终端。';
    } else if (state.needSetup) {
      empty.textContent = '首次使用请点「设」完成 API。展开后工具条在输入框下方、发送按钮左侧。';
    } else {
      empty.textContent = '开始对话，或点「+」选择服务商新建标签。';
    }
    if (empty) empty.style.display = '';
  }

  function appendMessageDom(role, content, ts, msgId) {
    var w = document.createElement('article');
    w.className = 'm ' + role;
    if (msgId) w.dataset.msgId = msgId;
    var title = role === 'user' ? 'User' : 'Assistant';
    var timeStr = ts
      ? (function () {
          try {
            return new Date(ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
          } catch (e) {
            return '';
          }
        })()
      : new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    var normalized = preMarkdownForChat(content);
    var bodyHtml = md(normalized);
    if (!String(bodyHtml || '').replace(/\s/g, '') && String(normalized || '').trim())
      bodyHtml = '<p>' + esc(normalized).replace(/\n/g, '<br>') + '</p>';
    w.innerHTML =
      '<div class="mh"><span>' +
      title +
      '</span><span>' +
      timeStr +
      '</span></div><div class="mb">' +
      bodyHtml +
      '</div>';
    msgs.appendChild(w);
  }

  function renderMessageNode(node, role, content, ts) {
    if (!node) return;
    var title = role === 'user' ? 'User' : 'Assistant';
    var timeStr = ts
      ? (function () {
          try {
            return new Date(ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
          } catch (e) {
            return '';
          }
        })()
      : new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    var normalized = preMarkdownForChat(content);
    var bodyHtml = md(normalized);
    if (!String(bodyHtml || '').replace(/\s/g, '') && String(normalized || '').trim())
      bodyHtml = '<p>' + esc(normalized).replace(/\n/g, '<br>') + '</p>';
    node.className = 'm ' + role;
    node.innerHTML =
      '<div class="mh"><span>' +
      title +
      '</span><span>' +
      timeStr +
      '</span></div><div class="mb">' +
      bodyHtml +
      '</div>';
  }

  function genMsgId() {
    return 'm-' + Date.now() + '-' + Math.random().toString(36).slice(2, 9);
  }

  function ensureAssistantDraft(s, seedText) {
    if (!s) return null;
    var last = s.history && s.history.length ? s.history[s.history.length - 1] : null;
    if (last && last.role === 'assistant' && last._draft) return last;
    var n = {
      _id: genMsgId(),
      _draft: true,
      role: 'assistant',
      content: String(seedText || '').trim() || '思考中...',
      ts: new Date().toISOString()
    };
    s.history.push(n);
    appendMessageDom(n.role, n.content, n.ts, n._id);
    emptyState();
    scrollMsgsToLatest();
    return n;
  }

  function updateHistoryMessageById(s, msgId, content, persistNow) {
    if (!s || !msgId) return false;
    var found = null;
    for (var i = s.history.length - 1; i >= 0; i--) {
      var m = s.history[i];
      if (m && m._id === msgId) {
        found = m;
        break;
      }
    }
    if (!found) return false;
    found.content = String(content || '').trim() || found.content || '思考中...';
    var node = msgs.querySelector('article.m[data-msg-id="' + msgId + '"]');
    if (node && s.id === state.activeSessionId) renderMessageNode(node, found.role, found.content, found.ts);
    if (persistNow) {
      persistSessions();
      pushSessionHistoryToStore(s);
      renderSessionTabs();
    }
    return true;
  }

  function removeHistoryMessageById(s, msgId, persistNow) {
    if (!s || !msgId || !Array.isArray(s.history)) return false;
    var idx = -1;
    for (var i = s.history.length - 1; i >= 0; i--) {
      if (s.history[i] && s.history[i]._id === msgId) {
        idx = i;
        break;
      }
    }
    if (idx < 0) return false;
    s.history.splice(idx, 1);
    var node = msgs.querySelector('article.m[data-msg-id="' + msgId + '"]');
    if (node) node.remove();
    if (persistNow) {
      persistSessions();
      pushSessionHistoryToStore(s);
      renderSessionTabs();
      emptyState();
    }
    return true;
  }

  function rebuildMsgList() {
    msgs.querySelectorAll('article.m').forEach(function (n) {
      n.remove();
    });
    var s = activeSession();
    if (!s) {
      emptyState();
      return;
    }
    if (isCliSession(s)) {
      // CLI 模式不渲染气泡历史（独立终端界面）
      emptyState();
      syncChatViewMode();
      return;
    }
    s.history.forEach(function (item) {
      if (!item || !item.role) return;
      var raw = item.content != null ? String(item.content) : '';
      var disp = raw.trim() ? raw : ocExtractMessageContentForHistory(item);
      if (!String(disp || '').trim()) disp = '（无正文）';
      appendMessageDom(item.role, disp, item.ts, item._id || '');
    });
    emptyState();
    scrollMsgsToLatest();
    syncChatViewMode();
  }

  function add(role, content) {
    var s = activeSession();
    if (!s) return;
    var ts = new Date().toISOString();
    var n = normalizeHistoryItem({ role: role, content: content, ts: ts });
    if (!n) return;
    n._id = genMsgId();
    s.history.push(n);
    persistSessions();
    pushSessionHistoryToStore(s);
    emptyState();
    appendMessageDom(n.role, n.content, n.ts, n._id);
    scrollMsgsToLatest();
    renderSessionTabs();
  }

  function clearChatSearchHit() {
    msgs.querySelectorAll('article.m.search-hit').forEach(function (n) {
      n.classList.remove('search-hit');
    });
  }

  function runChatSearchPrompt() {
    var kw = prompt('搜索聊天记录', state.chatSearchKeyword || '');
    if (kw == null) return;
    kw = String(kw || '').trim();
    if (!kw) {
      state.chatSearchKeyword = '';
      state.chatSearchCursor = -1;
      clearChatSearchHit();
      cstat('已清空搜索关键词');
      return;
    }
    var all = Array.prototype.slice.call(msgs.querySelectorAll('article.m'));
    var matched = all.filter(function (node) {
      return String(node.textContent || '').toLowerCase().indexOf(kw.toLowerCase()) >= 0;
    });
    if (!matched.length) {
      clearChatSearchHit();
      state.chatSearchKeyword = kw;
      state.chatSearchCursor = -1;
      cstat('未找到：' + kw, 'error');
      return;
    }
    if (state.chatSearchKeyword !== kw) state.chatSearchCursor = -1;
    state.chatSearchKeyword = kw;
    state.chatSearchCursor = (state.chatSearchCursor + 1) % matched.length;
    clearChatSearchHit();
    var target = matched[state.chatSearchCursor];
    target.classList.add('search-hit');
    try {
      target.scrollIntoView({ behavior: 'smooth', block: 'center' });
    } catch (_) {
      target.scrollIntoView();
    }
    cstat('搜索命中 ' + (state.chatSearchCursor + 1) + '/' + matched.length + '：' + kw, 'success');
  }

  function switchSession(id) {
    if (id === state.activeSessionId) return;
    var cur = activeSession();
    syncSessionFromForm(cur);
    pushSessionHistoryToStore(cur);
    persistSessions();
    state.activeSessionId = id;
    var target = activeSession();
    pullStoreHistoryToSession(target);
    syncFormFromSession(target);
    rebuildMsgList();
    renderSessionTabs();
    updateNeedSetup();
    refreshSendUi();
    if (target && target.provider === 'openclaw') hydrateOpenClawHistoryForSession(target, false);
    syncChatViewMode();
  }

  function pickProviderGridKeys() {
    var out = [];
    var seen = {};
    PROVIDER_PICK_ORDER.forEach(function (k) {
      if (P[k] && !seen[k]) {
        seen[k] = 1;
        out.push(k);
      }
    });
    Object.keys(P).forEach(function (k) {
      if (!seen[k]) out.push(k);
    });
    return out;
  }

  function fillNewSessionGrid() {
    if (!newSessionGrid) return;
    newSessionGrid.innerHTML = '';
    pickProviderGridKeys().forEach(function (k) {
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'ns-item';
      btn.dataset.pickProvider = k;
      var ico = document.createElement('span');
      ico.className = 'stab-ico';
      ico.setAttribute('aria-hidden', 'true');
      var im = document.createElement('img');
      bindProviderIconImg(im, k);
      ico.appendChild(im);
      var lab = document.createElement('span');
      lab.className = 'ns-lab';
      lab.textContent = P[k].label;
      btn.appendChild(ico);
      btn.appendChild(lab);
      newSessionGrid.appendChild(btn);
    });
  }

  function openNewSessionPick() {
    setSettings(false);
    setNspick(true);
    fillNewSessionGrid();
  }

  function closeNewSessionPick() {
    setNspick(false);
  }

  function createSessionWithProvider(pid) {
    if (!pid || !P[pid]) return;
    var cur = activeSession();
    syncSessionFromForm(cur);
    saveCfg(false);
    var p = P[pid];
    var sid = genId();
    var wantedOpenClawKey = openclawSessionKey ? String(openclawSessionKey.value || '').trim() : '';
    var s = {
      id: sid,
      provider: pid,
      model: p.transport === 'cli' ? '' : p.model,
      baseUrl: p.baseUrl,
      gatewaySessionKey: pid === 'openclaw' ? resolveOpenClawSessionKey(wantedOpenClawKey, 'agent:main:main') : '',
      history: []
    };
    state.sessions.push(s);
    state.activeSessionId = s.id;
    pullStoreHistoryToSession(s);
    persistSessions();
    syncFormFromSession(s);
    rebuildMsgList();
    renderSessionTabs();
    updateNeedSetup();
    closeNewSessionPick();
    cstat('已打开「' + p.label + '」新对话', 'success');
    if (pid === 'openclaw') hydrateOpenClawHistoryForSession(s, true);
    syncChatViewMode();
  }

  function removeSession(id) {
    if (state.sessions.length <= 1) {
      cstat('至少保留一个对话标签。', 'error');
      return;
    }
    var cur = activeSession();
    if (cur && cur.id === id) syncSessionFromForm(cur);
    var idx = -1;
    for (var i = 0; i < state.sessions.length; i++) {
      if (state.sessions[i].id === id) {
        idx = i;
        break;
      }
    }
    if (idx < 0) return;
    state.sessions.splice(idx, 1);
    if (state.activeSessionId === id) {
      state.activeSessionId = state.sessions[Math.max(0, idx - 1)].id;
      syncFormFromSession(activeSession());
      rebuildMsgList();
    }
    persistSessions();
    renderSessionTabs();
  }

  function downloadBlob(filename, text, mime) {
    var blob = new Blob([text], { type: mime || 'text/plain;charset=utf-8' });
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = filename;
    a.click();
    URL.revokeObjectURL(a.href);
  }

  function exportMarkdown() {
    var s = activeSession();
    if (!s || !s.history.length) {
      cstat('当前标签没有消息可导出。', 'error');
      return;
    }
    syncSessionFromForm(s);
    var lines = [];
    lines.push('# NiuMa Chat 导出');
    lines.push('');
    lines.push('- 服务商: ' + ((P[s.provider] || {}).label || s.provider));
    lines.push('- 模型: ' + s.model);
    lines.push('- 导出时间: ' + new Date().toLocaleString());
    lines.push('');
    s.history.forEach(function (m) {
      lines.push('## ' + (m.role === 'user' ? '用户' : '助手') + ' · ' + (m.ts || ''));
      lines.push('');
      lines.push(m.content);
      lines.push('');
    });
    downloadBlob('niuma-chat-' + s.id + '.md', lines.join('\n'), 'text/markdown;charset=utf-8');
    cstat('已导出 Markdown。', 'success');
  }

  function exportJson() {
    var s = activeSession();
    if (!s || !s.history.length) {
      cstat('当前标签没有消息可导出。', 'error');
      return;
    }
    syncSessionFromForm(s);
    var payload = {
      exportedAt: new Date().toISOString(),
      session: {
        id: s.id,
        provider: s.provider,
        providerLabel: (P[s.provider] || {}).label || s.provider,
        model: s.model,
        baseUrl: s.baseUrl,
        history: s.history
      }
    };
    downloadBlob('niuma-chat-' + s.id + '.json', JSON.stringify(payload, null, 2), 'application/json;charset=utf-8');
    cstat('已导出 JSON。', 'success');
  }

  function cstat(t, m) {
    chatStatus.textContent = t;
    chatStatus.className = 'st' + (m === 'error' ? ' error' : m === 'success' ? ' success' : '');
  }

  function isSessionSending(id) {
    if (!id) return false;
    return !!(state.sendingBySession && state.sendingBySession[id]);
  }

  function refreshSendUi() {
    var sid = state.activeSessionId || (activeSession() && activeSession().id) || '';
    var sending = isSessionSending(sid);
    var s = activeSession();
    if (isCliSession(s)) {
      // CLI 模式隐藏 composer，本按钮不作为主要入口；保持禁用避免误触
      send.disabled = true;
      send.textContent = 'CLI 模式';
      return;
    }
    send.disabled = sending;
    send.textContent = sending ? '发送中...' : '发送消息';
  }

  function setSessionSending(id, v) {
    if (!id) return;
    if (!state.sendingBySession) state.sendingBySession = {};
    if (v) state.sendingBySession[id] = true;
    else delete state.sendingBySession[id];
    refreshSendUi();
  }

  function cstatForSession(sid, t, m) {
    if (state.activeSessionId === sid) cstat(t, m);
  }

  function sstat(t, m) {
    cfgStatus.textContent = t;
    cfgStatus.className = 'st' + (m === 'error' ? ' error' : m === 'success' ? ' success' : '');
  }

  function fillProviders() {
    provider.innerHTML = Object.keys(P)
      .map(function (k) {
        return '<option value="' + k + '">' + P[k].label + '</option>';
      })
      .join('');
    buildProviderDdMenu();
    syncProviderDdUi();
  }

  function buildProviderDdMenu() {
    if (!providerDdMenu) return;
    providerDdMenu.innerHTML = '';
    Object.keys(P).forEach(function (k) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'dd-item';
      b.setAttribute('role', 'option');
      b.dataset.value = k;
      var im = document.createElement('img');
      bindProviderIconImg(im, k, 'dd-icon');
      var sp = document.createElement('span');
      sp.className = 'dd-label';
      sp.textContent = P[k].label;
      b.appendChild(im);
      b.appendChild(sp);
      b.addEventListener('click', function (e) {
        e.stopPropagation();
        provider.value = k;
        var ev = new Event('change', { bubbles: true });
        provider.dispatchEvent(ev);
        closeProviderDd();
      });
      providerDdMenu.appendChild(b);
    });
  }

  function syncProviderDdUi() {
    var pv = normalizeProviderId(provider.value);
    var k = pv && P[pv] ? pv : 'openai';
    var p = P[k] || P.openai;
    if (providerDdLabel) providerDdLabel.textContent = p.label;
    if (providerDdIcon) bindProviderIconImg(providerDdIcon, k, 'dd-icon');
    if (providerDdMenu) {
      providerDdMenu.querySelectorAll('.dd-item').forEach(function (el) {
        el.classList.toggle('dd-active', el.dataset.value === k);
      });
    }
  }

  function closeProviderDd() {
    if (providerDdMenu) providerDdMenu.hidden = true;
    if (providerDdBtn) providerDdBtn.setAttribute('aria-expanded', 'false');
  }

  function closeModelDd() {
    if (modelDdMenu) modelDdMenu.hidden = true;
    if (modelDdBtn) modelDdBtn.setAttribute('aria-expanded', 'false');
  }

  function toggleProviderDd() {
    if (!providerDdMenu) return;
    var open = providerDdMenu.hidden;
    closeModelDd();
    providerDdMenu.hidden = !open;
    if (providerDdBtn) providerDdBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
  }

  function toggleModelDd() {
    if (!modelDdMenu) return;
    var open = modelDdMenu.hidden;
    closeProviderDd();
    modelDdMenu.hidden = !open;
    if (modelDdBtn) modelDdBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
    if (open) ensureDynamicModelsForActiveProvider();
  }

  function uniqStrings(arr) {
    var out = [],
      seen = {};
    (arr || []).forEach(function (x) {
      var v = String(x || '').trim();
      if (!v || seen[v]) return;
      seen[v] = 1;
      out.push(v);
    });
    return out;
  }

  function getPresetModels(pid) {
    var p = P[pid] || P.openai;
    var staticModels = Array.isArray(p.models) ? p.models : [];
    var dynamicModels = (state.dynamicModels && state.dynamicModels[pid]) || [];
    return uniqStrings([].concat(dynamicModels, staticModels));
  }

  function modelListUrl(base) {
    var b = String(base || '').trim().replace(/\/+$/, '');
    if (!b) return '';
    return b + '/models';
  }

  function collectModelIdsDeep(v, out) {
    if (!v) return;
    if (Array.isArray(v)) {
      v.forEach(function (it) {
        collectModelIdsDeep(it, out);
      });
      return;
    }
    if (typeof v === 'string') {
      var s = v.trim();
      if (s) out.push(s);
      return;
    }
    if (typeof v !== 'object') return;
    var cand = [v.id, v.model, v.name, v.model_id, v.modelId];
    cand.forEach(function (x) {
      if (typeof x === 'string' && x.trim()) out.push(x.trim());
    });
    if (v.data) collectModelIdsDeep(v.data, out);
    if (v.models) collectModelIdsDeep(v.models, out);
    if (v.result) collectModelIdsDeep(v.result, out);
    if (v.items) collectModelIdsDeep(v.items, out);
  }

  async function fetchDynamicModels(pid) {
    pid = normalizeProviderId(pid);
    if (!(pid && P[pid])) return [];
    var prov = P[pid];
    if (prov.transport !== 'openai') return [];
    var url = modelListUrl(baseUrl.value || prov.baseUrl);
    if (!url) return [];
    var headers = { 'Content-Type': 'application/json' };
    var key = getApiKeyForProvider(pid);
    if (key) headers.Authorization = 'Bearer ' + key;
    var resp = await fetch(url, { method: 'GET', headers: headers });
    if (!resp.ok) throw new Error('HTTP ' + resp.status);
    var body = await resp.json().catch(function () { return {}; });
    var ids = [];
    collectModelIdsDeep(body, ids);
    return uniqStrings(ids).slice(0, 200);
  }

  async function ensureDynamicModelsForActiveProvider(force) {
    var pid = normalizeProviderId(provider.value);
    if (!(pid && P[pid])) return;
    if ((P[pid] || {}).transport === 'cli') return;
    var now = Date.now();
    var ttlMs = 5 * 60 * 1000;
    if (!force) {
      var at = (state.dynamicModelsFetchedAt && state.dynamicModelsFetchedAt[pid]) || 0;
      if (at && now - at < ttlMs) return;
    }
    try {
      var list = await fetchDynamicModels(pid);
      if (!state.dynamicModels) state.dynamicModels = {};
      if (!state.dynamicModelsFetchedAt) state.dynamicModelsFetchedAt = {};
      if (list && list.length) state.dynamicModels[pid] = list;
      state.dynamicModelsFetchedAt[pid] = now;
      if (normalizeProviderId(provider.value) === pid) {
        fillModels(pid, model.value.trim());
      }
    } catch (e) {
      if (!state.dynamicModelsFetchedAt) state.dynamicModelsFetchedAt = {};
      state.dynamicModelsFetchedAt[pid] = now;
    }
  }

  function fillModels(pid, sel) {
    var p = P[pid] || P.openai,
      o = ['<option value="">手动输入</option>'];
    getPresetModels(pid).forEach(function (m) {
      o.push('<option value="' + esc(m) + '">' + esc(m) + '</option>');
    });
    modelPreset.innerHTML = o.join('');
    var preset = getPresetModels(pid);
    modelPreset.value = sel && preset.indexOf(sel) >= 0 ? sel : '';
    buildModelDdMenu(pid);
    syncModelDdUi();
  }

  function buildModelDdMenu(pid) {
    if (!modelDdMenu) return;
    var p = P[pid] || P.openai;
    modelDdMenu.innerHTML = '';
    function addItem(val, label) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'dd-item';
      b.setAttribute('role', 'option');
      b.dataset.value = val;
      var im = document.createElement('img');
      bindProviderIconImg(im, pid, 'dd-icon');
      var sp = document.createElement('span');
      sp.className = 'dd-label';
      sp.textContent = label;
      b.appendChild(im);
      b.appendChild(sp);
      b.addEventListener('click', function (e) {
        e.stopPropagation();
        modelPreset.value = val;
        if (val) model.value = val;
        modelPreset.dispatchEvent(new Event('change', { bubbles: true }));
        closeModelDd();
      });
      modelDdMenu.appendChild(b);
    }
    addItem('', '手动输入');
    getPresetModels(pid).forEach(function (m) {
      addItem(m, m);
    });
  }

  function syncModelDdUi() {
    var pv = normalizeProviderId(provider.value);
    var k = pv && P[pv] ? pv : 'openai';
    var mp = modelPreset.value;
    var label = mp ? mp : '手动输入';
    if (modelDdLabel) modelDdLabel.textContent = label;
    if (modelDdIcon) bindProviderIconImg(modelDdIcon, k, 'dd-icon');
    if (modelDdMenu) {
      modelDdMenu.querySelectorAll('.dd-item').forEach(function (el) {
        el.classList.toggle('dd-active', el.dataset.value === mp);
      });
    }
  }

  function hint(pid) {
    var p = P[pid] || P.openai;
    if (p.transport === 'cli') {
      ph.textContent =
        p.label +
        ' 使用本机 ttyd 网页终端。Base URL 为终端页地址（默认 http://127.0.0.1:7681 ）。在「终端启动命令」中配置 cmd / PowerShell 等，保存后写入宿主配置并建议重启 ttyd。';
      return;
    }
    var m = {
        openai: 'OpenAI 兼容 chat/completions',
        anthropic: 'Anthropic messages 接口',
        gemini: 'Gemini generateContent 接口',
        openclaw: 'OpenClaw Gateway WebSocket（connect + chat.send）'
      },
      transportLabel = pid === 'ollama' ? '本地 Ollama（OpenAI 兼容 chat/completions）' : (m[p.transport] || p.transport);
    ph.textContent =
      p.label +
      ' 默认走 ' +
      transportLabel +
      '。如你使用中转站、反向代理或私有网关，也可以直接覆盖 Base URL 和 Model。';
  }

  function applyProvider(pid, keep) {
    pid = normalizeProviderId(pid);
    if (!(pid && P[pid])) pid = 'openai';
    var p = P[pid] || P.openai;
    provider.value = pid;
    fillModels(pid, p.transport === 'cli' ? '' : model.value.trim());
    hint(pid);
    if (!keep || !baseUrl.value.trim()) baseUrl.value = p.baseUrl;
    if (!keep || !model.value.trim()) model.value = p.transport === 'cli' ? '' : p.model;
    if (!systemPrompt.value.trim()) systemPrompt.value = SP;
    syncProviderDdUi();
    updateProviderFormLayout(pid);
  }

  function getApiKeyForProvider(pid) {
    pid = normalizeProviderId(pid);
    pid = pid && P[pid] ? pid : 'openai';
    return ((state.apiKeys && state.apiKeys[pid]) || '').trim();
  }

  function openClawEndpointFromCfg(cfg) {
    var raw = (cfg.baseUrl || '').trim();
    var token = (cfg.apiKey || '').trim();
    var host = '127.0.0.1';
    var port = 18789;
    try {
      var u = new URL(raw.indexOf('://') >= 0 ? raw : 'http://' + raw);
      host = u.hostname || host;
      if (u.port) port = parseInt(u.port, 10) || port;
      if (u.hash && u.hash.indexOf('token=') >= 0) {
        var sp = new URLSearchParams(u.hash.replace(/^#/, '?'));
        var ht = (sp.get('token') || '').trim();
        if (ht) token = ht;
      }
    } catch (e) {}
    if (!token || !host) return { ok: false };
    return { ok: true, host: host, port: port, token: token };
  }

  function openClawSessionKeyHintFromBaseUrl(rawBaseUrl) {
    var raw = String(rawBaseUrl || '').trim();
    if (!raw) return '';
    try {
      var u = new URL(raw.indexOf('://') >= 0 ? raw : 'http://' + raw);
      var qs = new URLSearchParams(u.search || '');
      var qk = String(qs.get('sessionKey') || qs.get('session') || qs.get('key') || '').trim();
      if (qk) return qk;
      if (u.hash) {
        var hs = new URLSearchParams(u.hash.replace(/^#/, '?'));
        var hk = String(hs.get('sessionKey') || hs.get('session') || hs.get('key') || '').trim();
        if (hk) return hk;
      }
    } catch (e) {}
    return '';
  }

  function ocNormalizeModelForSend(m) {
    var t = String(m || '').trim();
    if (!t) return '';
    var low = t.toLowerCase();
    if (low === 'gateway' || low === 'default') return '';
    return t;
  }

  function ocSessionRowsFromAny(v) {
    if (!v) return [];
    if (Array.isArray(v)) return v;
    if (Array.isArray(v.sessions)) return v.sessions;
    if (Array.isArray(v.items)) return v.items;
    if (Array.isArray(v.rows)) return v.rows;
    if (v.result && typeof v.result === 'object') return ocSessionRowsFromAny(v.result);
    if (v.data && typeof v.data === 'object') return ocSessionRowsFromAny(v.data);
    if (v.payload && typeof v.payload === 'object') return ocSessionRowsFromAny(v.payload);
    return [];
  }

  function ocSessionKeyFromSessionRow(row) {
    if (!row || typeof row !== 'object') return '';
    var direct = [
      row.sessionKey,
      row.key,
      row.session && row.session.sessionKey,
      row.session && row.session.key,
      row.entry && row.entry.sessionKey,
      row.entry && row.entry.key,
      row.data && row.data.sessionKey,
      row.data && row.data.key
    ];
    for (var i = 0; i < direct.length; i++) {
      var s = String(direct[i] == null ? '' : direct[i]).trim();
      if (s) return s;
    }
    return '';
  }

  function ocCanonicalSessionKey(k) {
    var s = String(k || '').trim();
    if (!s) return '';
    if (s.indexOf('agent:') === 0) return s;
    if (s === 'main') return 'agent:main:main';
    return 'agent:main:' + s;
  }

  function ocShortSessionKey(k) {
    var s = String(k || '').trim();
    if (!s) return '';
    var p = s.match(/^agent:[^:]+:(.+)$/);
    return p ? p[1] : s;
  }

  function ocSessionKeysEquivalent(a, b) {
    a = String(a || '').trim();
    b = String(b || '').trim();
    if (!a || !b) return false;
    if (a === b) return true;
    return ocCanonicalSessionKey(a) === ocCanonicalSessionKey(b) || ocShortSessionKey(a) === ocShortSessionKey(b);
  }

  function ocSessionPreviewItemsFromAny(v) {
    if (!v) return [];
    if (Array.isArray(v)) return v;
    if (Array.isArray(v.items)) return v.items;
    if (Array.isArray(v.messages)) return v.messages;
    if (Array.isArray(v.previews)) {
      for (var i = 0; i < v.previews.length; i++) {
        if (v.previews[i] && Array.isArray(v.previews[i].items)) return v.previews[i].items;
      }
    }
    if (v.result && typeof v.result === 'object') return ocSessionPreviewItemsFromAny(v.result);
    if (v.data && typeof v.data === 'object') return ocSessionPreviewItemsFromAny(v.data);
    if (v.payload && typeof v.payload === 'object') return ocSessionPreviewItemsFromAny(v.payload);
    return [];
  }

  function ocPreviewRowsFromAny(v) {
    if (!v) return [];
    if (Array.isArray(v.previews)) return v.previews;
    if (v.result && typeof v.result === 'object') return ocPreviewRowsFromAny(v.result);
    if (v.data && typeof v.data === 'object') return ocPreviewRowsFromAny(v.data);
    if (v.payload && typeof v.payload === 'object') return ocPreviewRowsFromAny(v.payload);
    return [];
  }

  function ocHistoryItemsFromPreviewItems(items) {
    return (Array.isArray(items) ? items : [])
      .map(function (it) {
        if (!it || typeof it !== 'object') return null;
        var role = normalizeRole(it.role);
        var text = String(it.text || it.content || '').trim();
        if (!role || !text) return null;
        if (role === 'tool' || role === 'system') return null;
        return { role: role === 'assistant' ? 'assistant' : 'user', content: text, ts: ensureIsoTime(it.ts || it.timestamp || it.createdAt) };
      })
      .filter(Boolean);
  }

  function ocModelFromSessionRow(row) {
    if (!row || typeof row !== 'object') return '';
    var direct = [
      row.modelIdentifier,
      row.model,
      row.modelName,
      row.model_name,
      row.session && row.session.modelIdentifier,
      row.session && row.session.model,
      row.session && row.session.modelName,
      row.session && row.session.model_name,
      row.agentRuntime && row.agentRuntime.modelIdentifier,
      row.agentRuntime && row.agentRuntime.model,
      row.agentRuntime && row.agentRuntime.modelName,
      row.effectiveModel,
      row.effective_model
    ];
    for (var i = 0; i < direct.length; i++) {
      var s = String(direct[i] == null ? '' : direct[i]).trim();
      if (s) return s;
    }
    return '';
  }

  async function ocResolveSessionMeta(cfg, wantedSessionKey) {
    var out = { sessionKey: String(wantedSessionKey || '').trim(), canonicalKey: '', model: '', row: null, previewItems: [] };
    if (!out.sessionKey) return out;
    var now = Date.now();
    var cacheKey = [String(cfg.baseUrl || '').trim(), out.sessionKey].join('|');
    if (!state.openclawMetaCache || typeof state.openclawMetaCache !== 'object') state.openclawMetaCache = {};
    var cached = state.openclawMetaCache[cacheKey];
    if (cached && now - Number(cached.ts || 0) < 15000) {
      return {
        sessionKey: String(cached.sessionKey || out.sessionKey),
        canonicalKey: String(cached.canonicalKey || ''),
        model: String(cached.model || ''),
        row: cached.row || null,
        previewItems: cached.previewItems || []
      };
    }
    try {
      var preview = await openClawRpc(cfg, 'sessions.preview', { keys: [out.sessionKey] }, 3500);
      out.previewItems = ocSessionPreviewItemsFromAny(preview);
      var previews = ocPreviewRowsFromAny(preview);
      if (previews.length) {
        var pk = ocSessionKeyFromSessionRow(previews[0]);
        if (pk) {
          out.sessionKey = pk;
          out.canonicalKey = ocCanonicalSessionKey(pk);
        }
      }
    } catch (ePreview) {}
    try {
      var sub = await openClawRpc(cfg, 'sessions.messages.subscribe', { key: out.sessionKey }, 3500);
      var subKey = ocSessionKeyFromSessionRow(sub);
      if (subKey) out.canonicalKey = subKey;
    } catch (eSub) {}
    if (!out.canonicalKey) out.canonicalKey = ocCanonicalSessionKey(out.sessionKey);
    try {
      var listed = await openClawRpc(cfg, 'sessions.list', {}, 3500);
      var defaults = listed && listed.defaults ? listed.defaults : listed && listed.payload && listed.payload.defaults ? listed.payload.defaults : null;
      var rows = ocSessionRowsFromAny(listed);
      if (rows.length) {
        state.openclawSessionRows = rows;
        state.openclawSessionRowsFetchedAt = Date.now();
        renderOpenClawSessionOptions();
      }
      for (var i = 0; i < rows.length; i++) {
        var k = ocSessionKeyFromSessionRow(rows[i]);
        if (!k) continue;
        if (ocSessionKeysEquivalent(k, out.sessionKey) || ocSessionKeysEquivalent(k, out.canonicalKey)) {
          out.row = rows[i];
          out.sessionKey = k;
          out.canonicalKey = ocCanonicalSessionKey(k);
          var m = ocModelFromSessionRow(rows[i]);
          if (m) out.model = m;
          break;
        }
      }
      if (!out.model && defaults) {
        var dm = defaults.model || defaults.modelIdentifier || defaults.primary || '';
        var dp = defaults.modelProvider || defaults.provider || '';
        out.model = dp && dm && String(dm).indexOf('/') < 0 ? String(dp) + '/' + String(dm) : String(dm || '');
      }
    } catch (e1) {}
    state.openclawMetaCache[cacheKey] = {
      ts: now,
      sessionKey: out.sessionKey,
      canonicalKey: out.canonicalKey || '',
      model: out.model || '',
      row: out.row || null,
      previewItems: out.previewItems || []
    };
    return out;
  }

  function ocGetSessionMessagePayload(msg) {
    if (!msg || typeof msg !== 'object') return null;
    var t = String(msg.type || '').toLowerCase();
    var e = String(msg.event || msg.method || '').toLowerCase();
    if (e === 'session.message') return msg.payload || msg.params || msg.result || msg;
    if (t === 'event' || t === 'push' || t === 'notification' || t === 'broadcast') {
      var w = msg.payload || msg.params;
      if (w && typeof w === 'object' && String(w.event || w.type || '').toLowerCase() === 'session.message') {
        return w.payload || w.message || w;
      }
    }
    return null;
  }

  function ocRoleFromSessionMessage(pl) {
    if (!pl || typeof pl !== 'object') return '';
    return ocRoleFromHistoryItem(pl.message || pl.item || pl.entry || pl);
  }

  function ocSessionMessageDone(pl) {
    if (!pl || typeof pl !== 'object') return false;
    var s = String(pl.state || pl.status || pl.phase || '').toLowerCase();
    return s === 'final' || s === 'done' || s === 'completed' || s === 'finished' || pl.done === true || pl.finished === true;
  }

  function ocSessionRowLabel(row) {
    if (!row || typeof row !== 'object') return '';
    var bits = [];
    var k = ocSessionKeyFromSessionRow(row);
    var label = row.displayName || row.label || row.name || '';
    var kind = row.kind || row.chatType || '';
    var updated = row.updatedAt || row.timestamp || row.ts || '';
    if (label) bits.push(String(label));
    if (kind) bits.push(String(kind));
    if (updated) {
      try {
        bits.push(new Date(Number(updated) || updated).toLocaleString());
      } catch (e) {}
    }
    return bits.length ? bits.join(' / ') : k;
  }

  function renderOpenClawSessionOptions() {
    if (!openclawSessionOptions) return;
    var rows = Array.isArray(state.openclawSessionRows) ? state.openclawSessionRows : [];
    openclawSessionOptions.innerHTML = rows
      .map(function (row) {
        var k = ocSessionKeyFromSessionRow(row);
        if (!k) return '';
        return '<option value="' + esc(k) + '" label="' + esc(ocSessionRowLabel(row)) + '"></option>';
      })
      .join('');
    if (openclawSessionHint && rows.length) {
      openclawSessionHint.textContent =
        openClawSessionPolicyValue() === 'follow'
          ? '已读取 OpenClaw 后台会话 ' + rows.length + ' 个；当前为“跟随后台”，将优先使用你选择的真实会话 key。'
          : '已读取 OpenClaw 后台会话 ' + rows.length + ' 个；当前为“稳定(main)”，发送时固定使用 agent:main:main。';
    }
  }

  async function refreshOpenClawSessionRows(force) {
    if (state.openclawSessionRowsLoading) return;
    var now = Date.now();
    if (!force && state.openclawSessionRowsFetchedAt && now - state.openclawSessionRowsFetchedAt < 20000) return;
    var s = activeSession();
    var cfg = {
      provider: 'openclaw',
      baseUrl: (s && s.provider === 'openclaw' && s.baseUrl ? s.baseUrl : baseUrl.value || (P.openclaw && P.openclaw.baseUrl) || '').trim(),
      apiKey: getApiKeyForProvider('openclaw')
    };
    if (!openClawEndpointFromCfg(cfg).ok) return;
    state.openclawSessionRowsLoading = true;
    try {
      var listed = await openClawRpc(cfg, 'sessions.list', {}, 6000);
      var rows = ocSessionRowsFromAny(listed);
      rows.sort(function (a, b) {
        return Number(b.updatedAt || b.timestamp || 0) - Number(a.updatedAt || a.timestamp || 0);
      });
      state.openclawSessionRows = rows;
      state.openclawSessionRowsFetchedAt = Date.now();
      renderOpenClawSessionOptions();
    } catch (e) {
    } finally {
      state.openclawSessionRowsLoading = false;
    }
  }

  function updateNeedSetup() {
    var s = activeSession();
    if (!s) {
      state.needSetup = true;
      return;
    }
    var sp = normalizeProviderId(s.provider);
    var p = P[sp] || P.openai;
    if (p.transport === 'cli') {
      state.needSetup = false;
      return;
    }
    var url = (s.baseUrl || '').trim() || baseUrl.value.trim() || p.baseUrl;
    var m = (s.model || '').trim() || model.value.trim();
    var k = getApiKeyForProvider(sp);
    if (p.transport === 'openclaw') {
      state.needSetup = !openClawEndpointFromCfg({ baseUrl: url, apiKey: k, provider: sp }).ok;
      return;
    }
    if (sp === 'ollama') {
      state.needSetup = !url || !m;
      return;
    }
    state.needSetup = !k || !url || !m;
  }

  function loadCfg() {
    var d = {};
    try {
      d = JSON.parse(localStorage.getItem(LS) || localStorage.getItem(LEGACY_LS) || '{}') || {};
    } catch (e) {
      d = {};
    }
    migrateApiKeysFromStorage(d);
    if (openclawSessionPolicy) {
      var pol = String(d.openclawSessionPolicy || '').trim();
      openclawSessionPolicy.value = pol === 'follow' ? 'follow' : 'stable';
    }
    systemPrompt.value = Object.prototype.hasOwnProperty.call(d, 'systemPrompt') ? String(d.systemPrompt) : SP;
    if (ttydShellCommand) ttydShellCommand.value = d.ttydShell != null ? String(d.ttydShell) : '';
    loadNiumaHistoryStore();

    loadSessions();

    if (state.sessions.length === 0) {
      var dp = normalizeProviderId(d.provider);
      var pid = dp && P[dp] ? dp : 'openai';
      provider.value = pid;
      applyProvider(pid, true);
      if (d.baseUrl) baseUrl.value = d.baseUrl;
      if (d.model) model.value = d.model;
      fillModels(pid, model.value.trim());
      var s0 = createSessionFromForm();
      state.sessions = [s0];
      state.activeSessionId = s0.id;
      persistSessions();
      apiKey.value = state.apiKeys[pid] || '';
      refreshApiKeyField(pid);
      provider.dataset.prevProv = pid;
    } else {
      ensureSessions();
      state.sessions.forEach(function (sx) {
        pullStoreHistoryToSession(sx);
      });
      syncFormFromSession(activeSession());
      fillModels(provider.value, model.value.trim());
    }

    state.sessions.forEach(function (sx) {
      pushSessionHistoryToStore(sx);
    });

    updateNeedSetup();
    updateProviderFormLayout(normalizeProviderId(provider.value));
    {
      var act = activeSession();
      var skipApiHint = act && isCliSession(act);
      sstat(
        skipApiHint
          ? '配置与对话已从本地恢复。'
          : state.needSetup
            ? '首次使用请先完成 API 设置。'
            : '配置与对话已从本地恢复。',
        !skipApiHint && state.needSetup ? '' : 'success'
      );
    }
    renderSessionTabs();
    rebuildMsgList();
    refreshSendUi();
    var sAct = activeSession();
    if (sAct && normalizeProviderId(sAct.provider) === 'openclaw') hydrateOpenClawHistoryForSession(sAct, false);
    ensureDynamicModelsForActiveProvider();
  }

  function saveCfg(ok) {
    var cur = activeSession();
    syncSessionFromForm(cur);
    var pv = normalizeProviderId(provider.value);
    var pid = pv && P[pv] ? pv : 'openai';
    if (!state.apiKeys) state.apiKeys = {};
    state.apiKeys[pid] = apiKey.value.trim();
    var d = {
      provider: pid,
      apiKeys: state.apiKeys,
      baseUrl: baseUrl.value.trim(),
      model: model.value.trim(),
      openclawSessionPolicy: openClawSessionPolicyValue(),
      systemPrompt: systemPrompt.value.trim(),
      ttydShell: ttydShellCommand ? ttydShellCommand.value.trim() : ''
    };
    localStorage.setItem(LS, JSON.stringify(d));
    persistSessions();
    updateNeedSetup();
    sstat(ok ? '设置已保存到本地。' : '配置会自动保存到本地。', ok ? 'success' : '');
    renderSessionTabs();
    return d;
  }

  function reset() {
    localStorage.removeItem(LS);
    localStorage.removeItem(LEGACY_LS);
    localStorage.removeItem(SESSIONS_LS);
    state.apiKeys = {};
    apiKey.value = '';
    systemPrompt.value = SP;
    applyProvider('openai', false);
    fillModels('openai', model.value.trim());
    refreshApiKeyField('openai');
    state.sessions = [];
    state.activeSessionId = '';
    loadCfg();
    state.needSetup = true;
    sstat('已重置：各服务商密钥与对话已清空，请分别填写。', '');
    setSettings(true);
  }

  function buildSendCfg() {
    var s = activeSession();
    if (!s) return null;
    syncSessionFromForm(s);
    var sp = normalizeProviderId(s.provider);
    var pid = sp && P[sp] ? sp : 'openai';
    var p = P[pid] || P.openai;
    var bu = (s.baseUrl || '').trim() || p.baseUrl;
    return {
      provider: pid,
      model: p.transport === 'cli' ? '' : pid === 'openclaw' ? 'gateway' : (s.model || '').trim() || p.model,
      baseUrl: bu,
      openclawSessionKey:
        pid === 'openclaw'
          ? resolveOpenClawSessionKey(String(s.gatewaySessionKey || '').trim(), openClawSessionKeyHintFromBaseUrl(bu) || getOpenClawSessionKey(s))
          : '',
      apiKey: getApiKeyForProvider(pid),
      systemPrompt: systemPrompt.value.trim()
    };
  }

  function oaUrl(u) {
    u = String(u || '').replace(/\/+$/, '');
    if (/\/chat\/completions$/i.test(u)) return u;
    if (/\/v\d+(?:\.\d+)?$/i.test(u)) return u + '/chat/completions';
    return u + '/chat/completions';
  }

  function claudeUrl(u) {
    u = String(u || '').replace(/\/+$/, '');
    if (/\/v1\/messages$/i.test(u)) return u;
    if (/\/v1$/i.test(u)) return u + '/messages';
    return u + '/v1/messages';
  }

  function geminiUrl(u, m, k) {
    u = String(u || '').replace(/\/+$/, '');
    var p = '/models/' + encodeURIComponent(m) + ':generateContent?key=' + encodeURIComponent(k);
    if (/\/v1beta$/i.test(u) || /\/v1$/i.test(u)) return u + p;
    return u + '/v1beta' + p;
  }

  function norm(c) {
    if (typeof c === 'string') return c;
    if (Array.isArray(c))
      return c
        .map(function (p) {
          if (typeof p === 'string') return p;
          if (p && typeof p.text === 'string') return p.text;
          return '';
        })
        .join('\n')
        .trim();
    return '';
  }

  function oaMsgs(cfg) {
    var m = [];
    if (cfg.systemPrompt) m.push({ role: 'system', content: cfg.systemPrompt });
    var h = activeSession() ? activeSession().history : [];
    h.forEach(function (i) {
      m.push({ role: i.role, content: i.content });
    });
    return m;
  }

  function claudeMsgs() {
    var h = activeSession() ? activeSession().history : [];
    return h.map(function (i) {
      return { role: i.role === 'assistant' ? 'assistant' : 'user', content: i.content };
    });
  }

  function geminiMsgs() {
    var h = activeSession() ? activeSession().history : [];
    return h.map(function (i) {
      return { role: i.role === 'assistant' ? 'model' : 'user', parts: [{ text: i.content }] };
    });
  }

  async function reqOpenAI(cfg) {
    var h = { 'Content-Type': 'application/json' };
    if (cfg.apiKey) h.Authorization = 'Bearer ' + cfg.apiKey;
    var r = await fetch(oaUrl(cfg.baseUrl), {
      method: 'POST',
      headers: h,
      body: JSON.stringify({ model: cfg.model, messages: oaMsgs(cfg), temperature: 0.7 })
    });
    if (!r.ok) throw new Error('HTTP ' + r.status + ': ' + (await r.text()));
    var d = await r.json(),
      c = '';
    try {
      c = norm(d.choices[0].message.content);
    } catch (e) {
      c = '';
    }
    if (!c) throw new Error('响应中没有可显示的内容。');
    return c;
  }

  async function reqClaude(cfg) {
    var r = await fetch(claudeUrl(cfg.baseUrl), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-api-key': cfg.apiKey, 'anthropic-version': '2023-06-01' },
      body: JSON.stringify({
        model: cfg.model,
        system: cfg.systemPrompt || '',
        max_tokens: 2048,
        messages: claudeMsgs()
      })
    });
    if (!r.ok) throw new Error('HTTP ' + r.status + ': ' + (await r.text()));
    var d = await r.json(),
      c = '';
    try {
      c = (d.content || [])
        .map(function (p) {
          return p && p.type === 'text' ? p.text || '' : '';
        })
        .join('\n')
        .trim();
    } catch (e) {
      c = '';
    }
    if (!c) throw new Error('响应中没有可显示的内容。');
    return c;
  }

  async function reqGemini(cfg) {
    var body = { contents: geminiMsgs(), generationConfig: { temperature: 0.7 } };
    if (cfg.systemPrompt) body.systemInstruction = { parts: [{ text: cfg.systemPrompt }] };
    var r = await fetch(geminiUrl(cfg.baseUrl, cfg.model, cfg.apiKey), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });
    if (!r.ok) throw new Error('HTTP ' + r.status + ': ' + (await r.text()));
    var d = await r.json(),
      c = '';
    try {
      var parts = (((d.candidates || [])[0] || {}).content || {}).parts || [];
      c = parts
        .map(function (p) {
          return p && typeof p.text === 'string' ? p.text : '';
        })
        .join('\n')
        .trim();
    } catch (e) {
      c = '';
    }
    if (!c) throw new Error('响应中没有可显示的内容。');
    return c;
  }

  function ocExtractText(v) {
    if (v == null) return '';
    if (typeof v === 'object')
      return String(v.text || v.content || v.message || v.body || v.value || '').trim();
    var s = String(v).trim();
    if (!s) return '';
    try {
      var o = JSON.parse(s);
      if (o && typeof o === 'object') return String(o.text || o.content || o.message || s).trim();
    } catch (e) {}
    return s;
  }

  function ocCollectTextDeep(v, out) {
    if (v == null) return;
    if (typeof v === 'string') {
      var t = v.trim();
      if (t) out.push(t);
      return;
    }
    if (Array.isArray(v)) {
      for (var i = 0; i < v.length; i++) ocCollectTextDeep(v[i], out);
      return;
    }
    if (typeof v === 'object') {
      if (typeof v.text === 'string' && v.text.trim()) out.push(v.text.trim());
      if (typeof v.message === 'string' && v.message.trim()) out.push(v.message.trim());
      if (typeof v.content === 'string' && v.content.trim()) out.push(v.content.trim());
      if (typeof v.body === 'string' && v.body.trim()) out.push(v.body.trim());
      if (typeof v.value === 'string' && v.value.trim()) out.push(v.value.trim());
      if (v.content && typeof v.content !== 'string') ocCollectTextDeep(v.content, out);
      if (v.delta) ocCollectTextDeep(v.delta, out);
      if (v.output) ocCollectTextDeep(v.output, out);
      if (v.outputText) ocCollectTextDeep(v.outputText, out);
      if (v.response) ocCollectTextDeep(v.response, out);
      if (v.result) ocCollectTextDeep(v.result, out);
      if (v.data) ocCollectTextDeep(v.data, out);
      if (v.payload) ocCollectTextDeep(v.payload, out);
      if (v.message && typeof v.message !== 'string') ocCollectTextDeep(v.message, out);
      if (v.parts) ocCollectTextDeep(v.parts, out);
      if (v.output_text) ocCollectTextDeep(v.output_text, out);
      if (v.answer) ocCollectTextDeep(v.answer, out);
      if (v.assistant) ocCollectTextDeep(v.assistant, out);
      if (v.assistantText) ocCollectTextDeep(v.assistantText, out);
      if (v.assistant_text) ocCollectTextDeep(v.assistant_text, out);
      if (v.assistantMessage) ocCollectTextDeep(v.assistantMessage, out);
      if (v.assistant_message) ocCollectTextDeep(v.assistant_message, out);
      if (v.finalText) ocCollectTextDeep(v.finalText, out);
      if (v.final_text) ocCollectTextDeep(v.final_text, out);
      if (v.final) ocCollectTextDeep(v.final, out);
      if (Array.isArray(v.choices)) {
        for (var c = 0; c < v.choices.length; c++) {
          var ch = v.choices[c];
          if (ch && typeof ch === 'object') {
            ocCollectTextDeep(ch.message || ch.delta || ch, out);
          }
        }
      }
    }
  }

  /** OpenClaw broadcast("chat", payload)：正文在 message.content[].text，而非旧版 response.text */
  function ocExtractChatEventPayload(pl) {
    if (!pl || typeof pl !== 'object') return '';
    if (pl.state === 'error') return '';
    var msg =
      pl.message ||
      pl.assistant ||
      pl.assistantMessage ||
      pl.data ||
      pl.response ||
      pl.result ||
      pl.output ||
      pl.delta ||
      pl.payload;
    if (msg == null) msg = pl;
    if (typeof msg === 'string') return String(msg).trim();
    var acc = [];
    ocCollectTextDeep(msg, acc);
    if (acc.length) return acc.join('\n').trim();
    acc = [];
    ocCollectTextDeep(pl, acc);
    if (acc.length) return acc.join('\n').trim();
    return ocExtractText(msg) || ocExtractText(pl);
  }

  /**
   * 与 openclaw2 控制台一致：顶层常为 type:event + payload.event===chat，
   * 而非 msg.event===chat（否则 NiuMa 永远等不到 final，45s 超时）。
   */
  function ocGetChatBroadcastPayload(msg) {
    if (!msg || typeof msg !== 'object') return null;
    if (msg.payload != null && typeof msg.payload === 'object' && msg.event === 'chat') return msg.payload;
    var t = msg.type,
      e = msg.event;
    var isEventEnvelope =
      t === 'event' ||
      t === 'push' ||
      t === 'notification' ||
      t === 'broadcast' ||
      e === 'event' ||
      e === 'push' ||
      e === 'notification' ||
      e === 'broadcast';
    if (!isEventEnvelope) return null;
    var w = msg.payload || msg.params;
    if (!w || typeof w !== 'object') return null;
    var inner = String(w.event || w.type || '').toLowerCase();
    if (inner !== 'chat') return null;
    if (w.payload != null && typeof w.payload === 'object') return w.payload;
    return w;
  }

  function ocGetChatSideResultPayload(msg) {
    if (!msg || typeof msg !== 'object') return null;
    if (msg.payload != null && typeof msg.payload === 'object' && msg.event === 'chat.side_result') return msg.payload;
    var t = msg.type,
      e = msg.event;
    var isEventEnvelope =
      t === 'event' ||
      t === 'push' ||
      t === 'notification' ||
      t === 'broadcast' ||
      e === 'event' ||
      e === 'push' ||
      e === 'notification' ||
      e === 'broadcast';
    if (!isEventEnvelope) return null;
    var w = msg.payload || msg.params;
    if (!w || typeof w !== 'object') return null;
    var inner = String(w.event || w.type || '').toLowerCase();
    if (inner !== 'chat.side_result') return null;
    if (w.payload != null && typeof w.payload === 'object') return w.payload;
    return w;
  }

  function ocIsChatFinalState(pl) {
    if (!pl || typeof pl !== 'object') return false;
    var s = pl.state;
    if (s === 'final' || s === 'done' || s === 'completed' || s === 'finished') return true;
    if (pl.done === true || pl.finished === true) return true;
    return false;
  }

  function ocCollectNamedStringsDeep(v, names, out, depth) {
    if (!v || typeof v !== 'object' || depth > 7) return;
    if (Array.isArray(v)) {
      for (var i = 0; i < v.length; i++) ocCollectNamedStringsDeep(v[i], names, out, depth + 1);
      return;
    }
    for (var k in v) {
      if (!Object.prototype.hasOwnProperty.call(v, k)) continue;
      var val = v[k];
      var lk = String(k || '').toLowerCase();
      if (names[lk] && (typeof val === 'string' || typeof val === 'number')) {
        var s = String(val).trim();
        if (s) out.push(s);
      }
      if (val && typeof val === 'object') ocCollectNamedStringsDeep(val, names, out, depth + 1);
    }
  }

  function ocPayloadMatchesSession(v, expectedSessionKey) {
    var expected = String(expectedSessionKey || '').trim();
    if (!expected || !v || typeof v !== 'object') return true;
    var names = {
      sessionkey: 1,
      sessionid: 1,
      session_id: 1,
      key: 1,
      conversationid: 1,
      conversation_id: 1,
      threadid: 1,
      thread_id: 1
    };
    var found = [];
    ocCollectNamedStringsDeep(v, names, found, 0);
    if (!found.length) return true;
    for (var i = 0; i < found.length; i++) {
      var got = String(found[i] || '').trim();
      if (got === expected || ocSessionKeysEquivalent(got, expected)) return true;
    }
    return false;
  }

  function ocPayloadMatchesRequest(v, expectedRequestId) {
    var expected = String(expectedRequestId || '').trim();
    if (!expected || !v || typeof v !== 'object') return true;
    var names = {
      idempotencykey: 1,
      clientrequestid: 1,
      client_request_id: 1,
      runid: 1,
      run_id: 1
    };
    var found = [];
    ocCollectNamedStringsDeep(v, names, found, 0);
    if (!found.length) return true;
    for (var i = 0; i < found.length; i++) {
      var got = String(found[i] || '').trim();
      if (got === expected) return true;
    }
    return false;
  }

  function extractGatewayHistoryMessages(res) {
    if (!res) return [];
    if (Array.isArray(res)) return res;
    if (Array.isArray(res.messages)) return res.messages;
    if (Array.isArray(res.history)) return res.history;
    if (Array.isArray(res.data)) return res.data;
    if (Array.isArray(res.items)) return res.items;
    if (res.result && typeof res.result === 'object') return extractGatewayHistoryMessages(res.result);
    if (res.data && typeof res.data === 'object') return extractGatewayHistoryMessages(res.data);
    if (res.payload && typeof res.payload === 'object') return extractGatewayHistoryMessages(res.payload);
    return [];
  }

  function mapGatewayHistoryItem(m) {
    if (!m || typeof m !== 'object') return null;
    var role = ocRoleFromHistoryItem(m);
    if (!role) return null;
    var content = ocExtractMessageContentForHistory(m);
    if (!content) return null;
    return { role: role, content: content, ts: ensureIsoTime(m.ts || m.timestamp || m.createdAt || m.updatedAt) };
  }

  function ocNormForMatch(s) {
    return String(s == null ? '' : s)
      .replace(/\s+/g, ' ')
      .trim()
      .toLowerCase();
  }

  function ocPickAssistantFromHistory(rawMessages, sentText) {
    var arr = Array.isArray(rawMessages) ? rawMessages : [];
    if (!arr.length) return '';
    var rows = [];
    var loose = [];
    for (var i = 0; i < arr.length; i++) {
      var m = arr[i];
      if (!m || typeof m !== 'object') continue;
      var content = ocExtractMessageContentForHistory(m);
      if (content) loose.push(content);
      var role = ocRoleFromHistoryItem(m);
      if (!role || !content) continue;
      rows.push({ role: role, content: content });
    }
    var sentNorm = ocNormForMatch(sentText);
    if (!rows.length) {
      for (var q = loose.length - 1; q >= 0; q--) {
        var ln0 = ocNormForMatch(loose[q]);
        if (!ln0) continue;
        if (sentNorm && (ln0 === sentNorm || ln0.indexOf(sentNorm) >= 0 || sentNorm.indexOf(ln0) >= 0)) continue;
        return loose[q];
      }
      return '';
    }
    if (sentNorm) {
      for (var u = rows.length - 1; u >= 0; u--) {
        if (rows[u].role !== 'user') continue;
        var un = ocNormForMatch(rows[u].content);
        if (!un) continue;
        if (un === sentNorm || un.indexOf(sentNorm) >= 0 || sentNorm.indexOf(un) >= 0) {
          for (var a = rows.length - 1; a > u; a--) {
            if (rows[a].role === 'assistant') return rows[a].content;
          }
          break;
        }
      }
    }
    for (var z = rows.length - 1; z >= 0; z--) {
      if (rows[z].role === 'assistant') return rows[z].content;
    }
    for (var q2 = loose.length - 1; q2 >= 0; q2--) {
      var ln = ocNormForMatch(loose[q2]);
      if (!ln) continue;
      if (sentNorm && (ln === sentNorm || ln.indexOf(sentNorm) >= 0 || sentNorm.indexOf(ln) >= 0)) continue;
      return loose[q2];
    }
    return '';
  }

  function ocPickReadableTextDeep(v, sentText) {
    if (!v || typeof v !== 'object') return '';
    var acc = [];
    ocCollectTextDeep(v, acc);
    if (!acc.length) return '';
    var sentNorm = ocNormForMatch(sentText);
    for (var i = acc.length - 1; i >= 0; i--) {
      var t = String(acc[i] || '').trim();
      if (!t) continue;
      var n = ocNormForMatch(t);
      if (!n) continue;
      if (sentNorm && (n === sentNorm || n.indexOf(sentNorm) >= 0 || sentNorm.indexOf(n) >= 0)) continue;
      if (n.length <= 1) continue;
      return t;
    }
    return '';
  }

  function openClawRpc(cfg, method, params, timeoutMs) {
    var ep = openClawEndpointFromCfg(cfg);
    if (!ep.ok) return Promise.reject(new Error('Gateway token missing'));
    var wsUrl = 'ws://' + ep.host + ':' + ep.port + '/?token=' + encodeURIComponent(ep.token);
    var to = Math.max(3000, Number(timeoutMs) || 12000);
    return new Promise(function (resolve, reject) {
      var ws;
      try {
        ws = new WebSocket(wsUrl);
      } catch (e) {
        reject(e);
        return;
      }
      var done = false,
        seq = 0,
        connected = false,
        connectSent = false,
        rpcId = '';
      var timer = setTimeout(function () {
        finishErr(new Error('OpenClaw RPC timeout: ' + method));
      }, to);

      function finishOk(val) {
        if (done) return;
        done = true;
        clearTimeout(timer);
        try {
          ws.close();
        } catch (e) {}
        resolve(val);
      }
      function finishErr(err) {
        if (done) return;
        done = true;
        clearTimeout(timer);
        try {
          ws.close();
        } catch (e) {}
        reject(err);
      }
      function sendConnect() {
        if (connectSent) return;
        connectSent = true;
        seq += 1;
        var cid = 'connect-' + seq;
        ws.send(
          JSON.stringify({
            type: 'req',
            id: cid,
            method: 'connect',
            params: {
              minProtocol: 3,
              maxProtocol: 3,
              client: { id: 'openclaw-control-ui', version: 'niuma', platform: 'web', mode: 'webchat', instanceId: 'niuma-rpc-' + Date.now() },
              role: 'operator',
              scopes: ['operator.admin', 'operator.approvals', 'operator.pairing', 'operator.read', 'operator.write'],
              caps: [],
              auth: { token: ep.token }
            }
          })
        );
      }
      function sendRpc() {
        if (!connected || rpcId) return;
        seq += 1;
        rpcId = 'rpc-' + seq;
        ws.send(JSON.stringify({ type: 'req', id: rpcId, method: method, params: params || {} }));
      }
      ws.onopen = function () {
        sendConnect();
      };
      ws.onerror = function () {
        finishErr(new Error('OpenClaw websocket error'));
      };
      ws.onclose = function () {
        if (!done) finishErr(new Error('OpenClaw websocket closed'));
      };
      ws.onmessage = function (e) {
        var msg = null;
        try {
          msg = JSON.parse(e.data);
        } catch (ex) {
          return;
        }
        var ev = msg.event || msg.type || msg.method || '';
        if (ev === 'connect.challenge') {
          connectSent = false;
          sendConnect();
          return;
        }
        if (typeof msg.id === 'string' && msg.id.indexOf('connect-') === 0) {
          if (msg.error || msg.ok === false) {
            finishErr(new Error((msg.error && msg.error.message) || 'connect failed'));
            return;
          }
          connected = true;
          sendRpc();
          return;
        }
        if (!connected && ev === 'hello-ok') {
          connected = true;
          sendRpc();
          return;
        }
        if (rpcId && msg.id === rpcId) {
          if (msg.error || msg.ok === false) {
            finishErr(new Error((msg.error && msg.error.message) || 'rpc failed'));
            return;
          }
          var body = msg.result !== undefined ? msg.result : msg.payload !== undefined ? msg.payload : msg;
          finishOk(body);
        }
      };
    });
  }

  async function openClawRpcWithRetry(cfg, method, params, options) {
    var opt = options || {};
    var attempts = Math.max(1, Number(opt.attempts) || 3);
    var baseTimeoutMs = Math.max(3000, Number(opt.timeoutMs) || 12000);
    var timeoutStepMs = Math.max(0, Number(opt.timeoutStepMs) || 2000);
    var backoffMs = Array.isArray(opt.backoffMs) ? opt.backoffMs : [220, 700, 1500];
    var lastErr = null;
    for (var i = 0; i < attempts; i++) {
      var timeoutMs = baseTimeoutMs + timeoutStepMs * i;
      try {
        return await openClawRpc(cfg, method, params, timeoutMs);
      } catch (e) {
        lastErr = e;
        if (typeof dbgPush === 'function') {
          dbgPush('rpc', 'retry', { method: method, attempt: i + 1, attempts: attempts, timeoutMs: timeoutMs, error: e && e.message ? e.message : String(e) }, true);
        }
        if (i >= attempts - 1) break;
        var waitMs = Number(backoffMs[Math.min(i, backoffMs.length - 1)]);
        if (!(waitMs > 0)) waitMs = 200 * (i + 1);
        await new Promise(function(r) { setTimeout(r, waitMs); });
      }
    }
    if (lastErr) throw lastErr;
    throw new Error('OpenClaw RPC failed: ' + method);
  }

  async function hydrateOpenClawHistoryForSession(s, force) {
    if (!s || s.provider !== 'openclaw') return;
    if (s._historyHydrating) return;
    if (s._historyHydrated && !force) return;
    s._historyHydrating = true;
    try {
      pullStoreHistoryToSession(s);
      if (s.id === state.activeSessionId) rebuildMsgList();
      var cfg = {
        provider: s.provider,
        baseUrl: (s.baseUrl || '').trim() || (P.openclaw && P.openclaw.baseUrl) || '',
        apiKey: getApiKeyForProvider('openclaw')
      };
      var ep = openClawEndpointFromCfg(cfg);
      if (ep.ok) {
        var sk = getOpenClawSessionKey(s);
        var meta = await ocResolveSessionMeta(cfg, sk);
        if (meta && (meta.canonicalKey || meta.sessionKey)) sk = String(meta.canonicalKey || meta.sessionKey).trim() || sk;
        s.gatewaySessionKey = sk;
        if (meta && meta.row) s.openclawMeta = meta.row;
        if (meta && meta.model) s.model = String(meta.model).trim() || s.model;
        var rpcRes = await openClawRpcWithRetry(cfg, 'chat.history', { sessionKey: sk, limit: 100 }, {
          attempts: 3,
          timeoutMs: 10000,
          timeoutStepMs: 3500,
          backoffMs: [250, 900]
        });
        var gw = extractGatewayHistoryMessages(rpcRes).map(mapGatewayHistoryItem).filter(Boolean);
        if ((!gw.length || gw.length < 2) && meta && meta.previewItems && meta.previewItems.length) {
          gw = mergeHistoryList(gw, ocHistoryItemsFromPreviewItems(meta.previewItems));
        }
        /* 本地优先：避免网关 chat.history 占位项（content 空、仅有 id）与刚发送条目同 key 时盖住本地正文 */
        if (gw.length) s.history = mergeHistoryList(s.history || [], gw).slice(-400);
      }
      pushSessionHistoryToStore(s);
      persistSessions();
      if (s.id === state.activeSessionId) rebuildMsgList();
      s._historyHydrated = true;
    } catch (e) {
    } finally {
      s._historyHydrating = false;
    }
  }

  async function reqOpenClaw(cfg, hooks) {
    var ep = openClawEndpointFromCfg(cfg);
    if (!ep.ok) throw new Error('缺少 Gateway Token：请填写密钥，或将带 #token= 的控制台地址填入 Base URL。');
    var wsUrl = 'ws://' + ep.host + ':' + ep.port + '/?token=' + encodeURIComponent(ep.token);
    var h = activeSession() ? activeSession().history : [];
    var last = h[h.length - 1];
    if (!last || last.role !== 'user') throw new Error('内部错误：缺少用户消息。');
    var msgText = String(last.content != null ? last.content : '');
    if (!msgText.trim()) msgText = ocExtractMessageContentForHistory(last);
    cfg.systemPrompt = '';
    if (!String(msgText || '').trim()) throw new Error('上一条用户消息正文为空，请重新输入后发送。');
    if (cfg.systemPrompt && h.length === 1) {
      msgText = '【系统提示】\n' + cfg.systemPrompt + '\n\n' + msgText;
    }
    var s0 = activeSession();
    var sessionKey =
      String(cfg.openclawSessionKey || '').trim() ||
      openClawSessionKeyHintFromBaseUrl(cfg.baseUrl) ||
      getOpenClawSessionKey(s0);
    var meta = await ocResolveSessionMeta(cfg, sessionKey);
    var canonicalSessionKey = ocCanonicalSessionKey(sessionKey);
    if (meta && typeof meta === 'object') {
      if (meta.sessionKey) sessionKey = String(meta.sessionKey).trim();
      if (meta.canonicalKey) canonicalSessionKey = String(meta.canonicalKey).trim();
      if (meta.model) cfg.model = String(meta.model).trim();
    }
    if (!canonicalSessionKey) canonicalSessionKey = ocCanonicalSessionKey(sessionKey);
    var canUseSessionSend = !!(meta && meta.row && canonicalSessionKey);
    var sendModel = ocNormalizeModelForSend(cfg.model);
    dbgNewTrace('openclaw', canonicalSessionKey || sessionKey || '');
    dbgPush('prepare', 'build_request', {
      sessionKey: sessionKey,
      canonicalSessionKey: canonicalSessionKey,
      canUseSessionSend: canUseSessionSend,
      model: sendModel || ''
    }, true);
    dbgMark('prepare', 'ok');
    if (s0) {
      s0.gatewaySessionKey = canonicalSessionKey || sessionKey || s0.gatewaySessionKey;
      if (meta && meta.row) s0.openclawMeta = meta.row;
      if (cfg.model && String(cfg.model).trim()) s0.model = String(cfg.model).trim();
      if (openclawSessionKey && state.activeSessionId === s0.id) openclawSessionKey.value = s0.gatewaySessionKey || '';
      if (model && state.activeSessionId === s0.id && s0.model) model.value = s0.model;
      persistSessions();
      renderSessionTabs();
    }
    var instanceId = 'niuma-' + Date.now() + '-' + Math.random().toString(36).slice(2, 11);

    return new Promise(function (resolve, reject) {
      var ws;
      try {
        ws = new WebSocket(wsUrl);
        dbgMark('connect', 'run');
        dbgPush('connect', 'ws_create', { wsUrl: wsUrl.replace(/token=[^&]+/i, 'token=***') }, true);
      } catch (e) {
        dbgMark('connect', 'fail');
        reject(new Error('无法建立 WebSocket：' + (e && e.message ? e.message : String(e))));
        return;
      }
      var seq = 0;
      var settled = false;
      var authenticated = false;
      var challengeReceived = false;
      var connectSent = false;
      var chatMsgId = '';
      var subscribeMsgId = '';
      var subscribeSent = false;
      var sendMethod = 'sessions.send';
      var sendFallbackTriggered = false;
      var firstStreamSeen = false;
      var noStreamFallbackTimer = null;
      var pendingText = '';
      var finalizeTimer = null;
      var recoveringFinal = false;
      var hardTimeout = setTimeout(function () {
        if (pendingText.trim()) {
          emitProgress(true);
          settleResolve(pendingText.trim());
          return;
        }
        recoverFinalFromHistory(true);
      }, 75000);
      var lastEmitAt = 0;
      var lastEmitText = '';

      function emitProgress(force) {
        if (!hooks || typeof hooks.onProgress !== 'function') return;
        var textNow = String(pendingText || '');
        var now = Date.now();
        if (!force && textNow === lastEmitText && now - lastEmitAt < 80) return;
        lastEmitAt = now;
        lastEmitText = textNow;
        try {
          hooks.onProgress(textNow);
        } catch (e0) {}
      }

      function cleanup() {
        clearTimeout(hardTimeout);
        if (finalizeTimer) clearTimeout(finalizeTimer);
        if (noStreamFallbackTimer) clearTimeout(noStreamFallbackTimer);
      }

      function settleResolve(val) {
        if (settled) return;
        settled = true;
        dbgMark('done', 'ok');
        dbgPush('done', 'resolved', { textLength: String(val || '').length }, true);
        cleanup();
        try {
          ws.close();
        } catch (e) {}
        resolve(val);
      }

      function settleReject(err) {
        if (settled) return;
        settled = true;
        var em = err && err.message ? String(err.message) : String(err || 'unknown error');
        var isSchema = /unexpected property 'model'|modelIdentifier/i.test(em);
        var layer = isSchema ? 'gateway_schema' : /websocket|timeout|closed|连接|回查 history/i.test(em) ? 'transport' : 'gateway_runtime';
        var code = isSchema ? 'E_SCHEMA_UNEXPECTED_FIELD' : 'E_OPENCLAW_REQUEST_FAILED';
        var hint = isSchema
          ? 'OpenClaw 不接受 model/modelIdentifier 字段，请改用 sessions.send 或升级前后端协议版本。'
          : '检查 Gateway 地址、token、session key 与网关日志。';
        dbgFail(layer, code, em, hint);
        cleanup();
        try {
          ws.close();
        } catch (e) {}
        reject(err);
      }

      function armFinalize() {
        if (finalizeTimer) clearTimeout(finalizeTimer);
        finalizeTimer = setTimeout(function () {
          var t = pendingText.trim();
          if (t) settleResolve(t);
          else settleReject(new Error('响应中没有可显示的内容。'));
        }, 320);
      }

      function fail(err) {
        settleReject(err);
      }

      function okDone() {
        var t = pendingText.trim();
        if (t) settleResolve(t);
        else settleReject(new Error('响应中没有可显示的内容。'));
      }

      function recoverFinalFromHistory(fromTimeout) {
        if (recoveringFinal) return;
        recoveringFinal = true;
        dbgPush('stream', 'recover_history_start', { fromTimeout: fromTimeout === true }, true);
        fromTimeout = fromTimeout === true;
        (async function () {
          var waitList = fromTimeout ? [400, 1500, 3500] : [120, 360];
          var lastRpcRes = null;
          for (var i = 0; i < waitList.length; i++) {
            try {
              await new Promise(function (r) {
                setTimeout(r, waitList[i]);
              });
              var rpcRes = await openClawRpcWithRetry(
                cfg,
                'chat.history',
                { sessionKey: sessionKey, limit: fromTimeout ? 200 : 120 },
                {
                  attempts: fromTimeout ? 3 : 2,
                  timeoutMs: fromTimeout ? 8000 : 3500,
                  timeoutStepMs: fromTimeout ? 3000 : 1200,
                  backoffMs: fromTimeout ? [280, 900] : [160]
                }
              );
              lastRpcRes = rpcRes;
              dbgPush('stream', 'recover_history_try', { attempt: i + 1, waitMs: waitList[i] }, true);
              var raw = extractGatewayHistoryMessages(rpcRes);
              var picked = ocPickAssistantFromHistory(raw, msgText);
              if (picked && String(picked).trim()) {
                pendingText = String(picked).trim();
                emitProgress(true);
                settleResolve(pendingText);
                return;
              }
              var deepPicked = ocPickReadableTextDeep(rpcRes, msgText);
              if (deepPicked && String(deepPicked).trim()) {
                pendingText = String(deepPicked).trim();
                emitProgress(true);
                settleResolve(pendingText);
                return;
              }
              var prevRes = await openClawRpcWithRetry(
                cfg,
                'sessions.preview',
                { keys: [canonicalSessionKey || sessionKey] },
                {
                  attempts: fromTimeout ? 2 : 1,
                  timeoutMs: fromTimeout ? 7000 : 3200,
                  timeoutStepMs: 1500,
                  backoffMs: [180]
                }
              );
              var prevPicked = ocPickAssistantFromHistory(ocHistoryItemsFromPreviewItems(ocSessionPreviewItemsFromAny(prevRes)), msgText);
              if (prevPicked && String(prevPicked).trim()) {
                pendingText = String(prevPicked).trim();
                emitProgress(true);
                settleResolve(pendingText);
                return;
              }
            } catch (e0) {
            }
          }
          if (lastRpcRes) {
            var fallbackPicked = ocPickReadableTextDeep(lastRpcRes, msgText);
            if (fallbackPicked && String(fallbackPicked).trim()) {
              pendingText = String(fallbackPicked).trim();
              emitProgress(true);
              settleResolve(pendingText);
              return;
            }
          }
          if (pendingText.trim()) {
            emitProgress(true);
            settleResolve(pendingText.trim());
            return;
          }
          if (lastRpcRes && Array.isArray(lastRpcRes.messages) && lastRpcRes.messages.length) {
            var hasAssistantThinking = false;
            var hasAssistantToolCall = false;
            for (var mi = 0; mi < lastRpcRes.messages.length; mi++) {
              var hm = lastRpcRes.messages[mi];
              if (!hm || hm.role !== 'assistant' || !Array.isArray(hm.content)) continue;
              for (var ci = 0; ci < hm.content.length; ci++) {
                var cp = hm.content[ci];
                if (!cp || typeof cp !== 'object') continue;
                if (cp.type === 'thinking' && cp.thinking) hasAssistantThinking = true;
                if (cp.type === 'toolCall' || cp.type === 'tool_call') hasAssistantToolCall = true;
              }
            }
            if (hasAssistantThinking || hasAssistantToolCall) {
              if (!fromTimeout) {
                for (var w = 0; w < 3; w++) {
                  await new Promise(function(r){ setTimeout(r, 1800); });
                  try {
                    var lateRes = await openClawRpcWithRetry(
                      cfg,
                      'chat.history',
                      { sessionKey: canonicalSessionKey || sessionKey, limit: 200 },
                      { attempts: 1, timeoutMs: 6000, timeoutStepMs: 0, backoffMs: [0] }
                    );
                    var lateRaw = extractGatewayHistoryMessages(lateRes);
                    var latePicked = ocPickAssistantFromHistory(lateRaw, msgText);
                    if (latePicked && String(latePicked).trim()) {
                      pendingText = String(latePicked).trim();
                      emitProgress(true);
                      settleResolve(pendingText);
                      return;
                    }
                    lastRpcRes = lateRes;
                  } catch (eLate) {
                  }
                }
              }
              settleResolve('OpenClaw 已收到请求，但当前停留在工具调用/思考阶段，未产出最终可展示文本。请重试一次，或切换到无工具依赖模型。');
              return;
            }
          }
          if (fromTimeout) settleReject(new Error('OpenClaw 超时：已重试并回查 history，但仍未解析到可读正文。'));
          else settleReject(new Error('OpenClaw 已到 final，但回查 history 仍未解析到可读正文。'));
        })();
      }

      function sendConnectOnce() {
        if (connectSent) return;
        connectSent = true;
        seq += 1;
        var cid = 'connect-' + seq;
        var params = {
          minProtocol: 3,
          maxProtocol: 3,
          client: {
            /* 须与 Gateway 的 openclaw-control-ui 一致：webchat id 会在无设备身份时被 clearUnboundScopes 清空 scopes，导致 chat.send 报 missing scope: operator.write */
            id: 'openclaw-control-ui',
            version: 'niuma',
            platform: typeof navigator !== 'undefined' ? navigator.platform || 'web' : 'web',
            mode: 'webchat',
            instanceId: instanceId
          },
          role: 'operator',
          scopes: ['operator.admin', 'operator.approvals', 'operator.pairing', 'operator.read', 'operator.write'],
          caps: [],
          userAgent: typeof navigator !== 'undefined' ? navigator.userAgent || '' : '',
          locale: typeof navigator !== 'undefined' ? navigator.language || 'zh-CN' : 'zh-CN',
          auth: { token: ep.token }
        };
        try {
          dbgPush('connect', 'connect.req', { method: 'connect' }, true);
          ws.send(JSON.stringify({ type: 'req', id: cid, method: 'connect', params: params }));
        } catch (e) {
          fail(new Error('发送认证请求失败：' + (e && e.message ? e.message : String(e))));
        }
      }

      function sendChatMsg() {
        seq += 1;
        chatMsgId = 'msg-' + seq;
        sendMethod = canUseSessionSend ? 'sessions.send' : 'chat.send';
        var params =
          sendMethod === 'sessions.send'
            ? { key: canonicalSessionKey || sessionKey, message: msgText, idempotencyKey: chatMsgId }
            : { message: msgText, idempotencyKey: chatMsgId, sessionKey: sessionKey };
        // OpenClaw chat.send schema may reject model/modelIdentifier in some versions.
        // Keep payload minimal for compatibility; model routing is handled server-side/session-side.
        try {
          dbgMark('send', 'run');
          dbgPush('send', 'chat.req', { method: sendMethod, hasModel: false, hasModelIdentifier: false }, true);
          ws.send(
            JSON.stringify({
              type: 'req',
              id: chatMsgId,
              method: sendMethod,
              params: params
            })
          );
          if (sendMethod === 'sessions.send') {
            if (noStreamFallbackTimer) clearTimeout(noStreamFallbackTimer);
            noStreamFallbackTimer = setTimeout(function () {
              if (settled || firstStreamSeen || sendFallbackTriggered) return;
              sendFallbackTriggered = true;
              dbgPush('stream', 'fallback_to_chat_send', { reason: 'no_stream_after_sessions_send' }, true);
              try {
                seq += 1;
                chatMsgId = 'msg-' + seq;
                sendMethod = 'chat.send';
                ws.send(
                  JSON.stringify({
                    type: 'req',
                    id: chatMsgId,
                    method: 'chat.send',
                    params: { message: msgText, idempotencyKey: chatMsgId, sessionKey: sessionKey }
                  })
                );
              } catch (e2) {
                fail(new Error('降级补发 chat.send 失败：' + (e2 && e2.message ? e2.message : String(e2))));
              }
            }, 8000);
          }
        } catch (e) {
          fail(new Error('发送对话失败：' + (e && e.message ? e.message : String(e))));
        }
      }

      function sendSessionSubscribe() {
        if (!canonicalSessionKey || subscribeSent) {
          sendChatMsg();
          return;
        }
        subscribeSent = true;
        seq += 1;
        subscribeMsgId = 'sub-' + seq;
        try {
          ws.send(
            JSON.stringify({
              type: 'req',
              id: subscribeMsgId,
              method: 'sessions.messages.subscribe',
              params: { key: canonicalSessionKey }
            })
          );
        } catch (e) {
          sendChatMsg();
        }
      }

      function onFrame(msg) {
        var ev = msg.event || msg.type || msg.method || '';

        if (ev === 'connect.challenge') {
          challengeReceived = true;
          // Prevent duplicate connect requests on repeated/late challenges.
          if (authenticated || connectSent) return;
          sendConnectOnce();
          return;
        }

        if (typeof msg.id === 'string' && msg.id.indexOf('connect-') === 0) {
          if (msg.error || msg.ok === false) {
            var em = (msg.error && msg.error.message) || 'Gateway 认证失败';
            fail(new Error(String(em)));
            return;
          }
          if (msg.result !== undefined || msg.ok === true) {
            authenticated = true;
            dbgMark('connect', 'ok');
            dbgPush('connect', 'connect.ok', {}, true);
            sendSessionSubscribe();
          }
          return;
        }

        if (!authenticated && ev === 'hello-ok') {
          authenticated = true;
          sendSessionSubscribe();
          return;
        }

        if (!authenticated) return;

        if (subscribeMsgId && msg.type === 'res' && msg.id === subscribeMsgId) {
          sendChatMsg();
          return;
        }

        /* chat.send 先返回 type:res（仅 started），助手正文由 broadcast("chat") 推送 */
        if (msg.type === 'res' && msg.id === chatMsgId) {
          if (msg.error || msg.ok === false) {
            var er0 = (msg.error && msg.error.message) || JSON.stringify(msg.error || {});
            if (sendMethod === 'sessions.send' && /unknown method|invalid sessions\.send|session not found|webchat clients cannot/i.test(String(er0 || ''))) {
              sendMethod = 'chat.send';
              seq += 1;
              chatMsgId = 'msg-' + seq;
              ws.send(
                JSON.stringify({
                  type: 'req',
                  id: chatMsgId,
                  method: 'chat.send',
                  params: { message: msgText, idempotencyKey: chatMsgId, sessionKey: sessionKey }
                })
              );
              return;
            }
            fail(new Error(String(er0)));
            return;
          }
          // Some OpenClaw builds return assistant text directly in ack result/payload
          // instead of broadcast/session stream frames.
          var ackObj =
            msg.result && typeof msg.result === 'object'
              ? msg.result
              : msg.payload && typeof msg.payload === 'object'
              ? msg.payload
              : null;
          if (ackObj) {
            var ackTxt =
              ocExtractText(ackObj.text || ackObj.content || ackObj.message || '') ||
              ocExtractChatEventPayload(ackObj) ||
              ocPickReadableTextDeep(ackObj, msgText);
            if (ackTxt && String(ackTxt).trim()) {
              firstStreamSeen = true;
              pendingText = String(ackTxt).trim();
              dbgMark('stream', 'run');
              dbgPush('stream', 'ack.inline_text', { len: pendingText.length }, true);
              emitProgress(true);
              okDone();
              return;
            }
            if (ackObj.done || ackObj.finish_reason || ackObj.finished || ackObj.state === 'final' || ackObj.state === 'done' || ackObj.state === 'completed') {
              var ftxt = ocPickReadableTextDeep(ackObj, msgText);
              if (ftxt && String(ftxt).trim()) {
                firstStreamSeen = true;
                pendingText = String(ftxt).trim();
                dbgMark('stream', 'run');
                dbgPush('stream', 'ack.final_text', { len: pendingText.length }, true);
                emitProgress(true);
                okDone();
                return;
              }
            }
          }
          dbgMark('ack', 'ok');
          dbgPush('ack', 'chat.ack', { method: sendMethod }, true);
          return;
        }

        if (msg.id === chatMsgId && msg.error && msg.type !== 'res') {
          var er = (msg.error && msg.error.message) || JSON.stringify(msg.error);
          fail(new Error(String(er)));
          return;
        }

        var plSession = ocGetSessionMessagePayload(msg);
        if (plSession) {
          var sessOk =
            ocPayloadMatchesSession(msg, sessionKey) ||
            ocPayloadMatchesSession(plSession, sessionKey) ||
            ocPayloadMatchesSession(msg, canonicalSessionKey) ||
            ocPayloadMatchesSession(plSession, canonicalSessionKey);
          if (!sessOk) return;
          var sr = ocRoleFromSessionMessage(plSession);
          if (sr && sr !== 'assistant') {
            if (ocSessionMessageDone(plSession) && pendingText.trim()) okDone();
            return;
          }
          var sessionTxt = ocExtractMessageContentForHistory(plSession.message || plSession.item || plSession.entry || plSession);
          if (!sessionTxt) sessionTxt = ocExtractChatEventPayload(plSession);
          if (sessionTxt) {
            firstStreamSeen = true;
            pendingText = String(sessionTxt).trim();
            dbgMark('stream', 'run');
            dbgPush('stream', 'session.message', { len: pendingText.length }, true);
            emitProgress(false);
          }
          if (ocSessionMessageDone(plSession)) {
            if (pendingText.trim()) okDone();
            else recoverFinalFromHistory(false);
            return;
          }
          if (sessionTxt) armFinalize();
          return;
        }

        var plChat = ocGetChatBroadcastPayload(msg);
        if (plChat) {
          var chatSessionOk = ocPayloadMatchesSession(msg, sessionKey) || ocPayloadMatchesSession(plChat, sessionKey);
          var chatReqOk = ocPayloadMatchesRequest(msg, chatMsgId) || ocPayloadMatchesRequest(plChat, chatMsgId);
          if (!chatSessionOk || !chatReqOk) return;
          var pl = plChat;
          if (pl.state === 'error') {
            fail(new Error(String(pl.errorMessage || 'OpenClaw 对话出错')));
            return;
          }
          var chatTxt = ocExtractChatEventPayload(pl);
          if (chatTxt) {
            firstStreamSeen = true;
            /* delta：可能是增量片段（需拼接）或每帧全量快照（需整段替换） */
            if (pl.state === 'delta') {
              if (pendingText && chatTxt.length >= pendingText.length && chatTxt.indexOf(pendingText) === 0)
                pendingText = chatTxt;
              else pendingText += chatTxt;
            } else pendingText = chatTxt;
            dbgMark('stream', 'run');
            dbgPush('stream', 'chat.delta', { state: pl.state || '', len: pendingText.length }, true);
            emitProgress(false);
          }
          if (ocIsChatFinalState(pl)) {
            if (!pendingText.trim()) {
              var fallback = ocExtractText(
                pl.errorMessage || pl.stopReason || pl.reason || pl.status || pl.message || ''
              );
              if (fallback) pendingText = fallback;
            }
            if (!pendingText.trim()) {
              recoverFinalFromHistory(false);
              return;
            }
            if (!pendingText.trim()) {
              try {
                var dbg = JSON.stringify(pl);
                if (dbg && dbg.length > 2 && dbg.length < 8000)
                  pendingText =
                    '（Gateway 返回了 final 但未解析出正文，请升级脚本或核对 Gateway 版本。原始 payload 摘要）\n' +
                    dbg.slice(0, 4000);
              } catch (e3) {}
            }
            okDone();
            return;
          }
          if (pl.state === 'delta' && chatTxt) armFinalize();
          /* 部分 Gateway 只推 text/content，无 state */
          if (pl.state == null && chatTxt) armFinalize();
          return;
        }

        var sidePl = ocGetChatSideResultPayload(msg);
        if (sidePl) {
          var sideSessionOk = ocPayloadMatchesSession(msg, sessionKey) || ocPayloadMatchesSession(sidePl, sessionKey);
          var sideReqOk = ocPayloadMatchesRequest(msg, chatMsgId) || ocPayloadMatchesRequest(sidePl, chatMsgId);
          if (!sideSessionOk || !sideReqOk) return;
          var side = sidePl;
          var st = ocExtractText(side.text || side.message || side.content || '');
          if (!st && side.btw && typeof side.btw.question === 'string') st = side.btw.question.trim();
          if (st) {
            pendingText = st;
            emitProgress(false);
            armFinalize();
          }
          return;
        }

        var respPayload = msg.payload || (msg.result !== undefined && typeof msg.result === 'object' ? msg.result : null);
        /* 与 openclaw2：流式帧常带 msg.result 而非 ev===response，且可能无 id */
        var isResp =
          ev === 'response' ||
          ev === 'chat.response' ||
          (msg.result !== undefined && typeof msg.result === 'object' && respPayload) ||
          (msg.id === chatMsgId && respPayload);

        if (isResp && respPayload) {
          var respSessionOk = ocPayloadMatchesSession(msg, sessionKey) || ocPayloadMatchesSession(respPayload, sessionKey);
          var respReqOk = ocPayloadMatchesRequest(msg, chatMsgId) || ocPayloadMatchesRequest(respPayload, chatMsgId);
          if (!respSessionOk || !respReqOk) return;
          var piece =
            ocExtractText(respPayload.text || respPayload.content || respPayload.message || '') ||
            ocExtractChatEventPayload(respPayload);
          if (piece) {
            pendingText += piece;
            emitProgress(false);
          }
          if (respPayload.done || respPayload.finish_reason || respPayload.finished) {
            okDone();
            return;
          }
          if (piece) armFinalize();
          return;
        }

        if (ev === 'error' || msg.error) {
          var emsg = ocExtractText((msg.payload && msg.payload.message) || (msg.error && msg.error.message) || msg.error);
          fail(new Error(emsg || '服务端错误'));
          return;
        }

        var rest = msg.payload || msg.params || {};
        var rt =
          ocExtractText(rest.text || rest.content || rest.message || '') || ocExtractChatEventPayload(rest);
        if (rt && (msg.id === chatMsgId || msg.id == null || msg.id === '')) {
          var restSessionOk = ocPayloadMatchesSession(msg, sessionKey) || ocPayloadMatchesSession(rest, sessionKey);
          var restReqOk = ocPayloadMatchesRequest(msg, chatMsgId) || ocPayloadMatchesRequest(rest, chatMsgId);
          if (!restSessionOk || !restReqOk) return;
          pendingText += rt;
          emitProgress(false);
          armFinalize();
        }

        /* 兜底：信封未标 chat 但 payload 已是流式结构（仅在本连接已发 chat.send 后） */
        if (chatMsgId) {
          var silentEv = { health: 1, tick: 1, ping: 1, pong: 1, heartbeat: 1, typing: 1 };
          if (!silentEv[ev]) {
            var guess = msg.payload || msg.params;
            if (
              guess &&
              typeof guess === 'object' &&
              (guess.state === 'delta' ||
                guess.state === 'final' ||
                guess.state === 'done' ||
                guess.state === 'completed' ||
                guess.state === 'error')
            ) {
              var guessSessionOk = ocPayloadMatchesSession(msg, sessionKey) || ocPayloadMatchesSession(guess, sessionKey);
              var guessReqOk = ocPayloadMatchesRequest(msg, chatMsgId) || ocPayloadMatchesRequest(guess, chatMsgId);
              if (!guessSessionOk || !guessReqOk) return;
              if (guess.state === 'error') {
                fail(new Error(String(guess.errorMessage || 'OpenClaw 对话出错')));
                return;
              }
              var gt = ocExtractChatEventPayload(guess);
              if (gt) {
                if (guess.state === 'delta') {
                  if (pendingText && gt.length >= pendingText.length && gt.indexOf(pendingText) === 0) pendingText = gt;
                  else pendingText += gt;
                } else pendingText = gt;
                emitProgress(false);
                if (ocIsChatFinalState(guess)) okDone();
                else armFinalize();
                return;
              }
            }
          }
        }
      }

      ws.onmessage = function (e) {
        var msg;
        try {
          msg = JSON.parse(e.data);
        } catch (ex) {
          return;
        }
        try {
          onFrame(msg);
        } catch (ex2) {
          fail(new Error(ex2 && ex2.message ? ex2.message : String(ex2)));
        }
      };

      ws.onopen = function () {
        dbgPush('connect', 'ws.open', {}, true);
        setTimeout(function () {
          if (!authenticated && !challengeReceived) sendConnectOnce();
        }, 450);
      };

      ws.onerror = function () {
        dbgMark('connect', 'fail');
        settleReject(new Error('WebSocket 错误（请确认 OpenClaw Gateway 已在本机 ' + ep.host + ':' + ep.port + ' 运行）。'));
      };

      ws.onclose = function (e) {
        if (settled) return;
        if (authenticated && pendingText.trim()) {
          settleResolve(pendingText.trim());
          return;
        }
        settleReject(new Error('连接已关闭（code ' + e.code + '）。'));
      };
    });
  }

  async function sendChat() {
    var s = activeSession();
    if (!s || !s.id) return;
    var sid = s.id;
    if (isSessionSending(sid)) {
      cstatForSession(sid, '该标签仍在等待上一次响应，请稍候。', 'error');
      return;
    }
    var text = input.value.trim();
    if (!text) return;
    saveCfg(false);
    var cfg = buildSendCfg();
    if (!cfg) return;
    var p0 = P[cfg.provider] || P.openai;
    if (p0.transport === 'cli') {
      // CLI 原生界面：不依赖 Base URL / Model 校验，点击即打开专属终端
      add('user', text);
      input.value = '';
      cstatForSession(sid, '正在连接本机 ttyd 终端…');
      throttledNiumaCliOpen(true);
      return;
    }
    if (!cfg.baseUrl || !cfg.model) {
      cstatForSession(sid, '请先在设置里填写 Base URL 和 Model。', 'error');
      setSettings(true);
      return;
    }
    if (p0.transport !== 'openclaw' && cfg.provider !== 'ollama' && !cfg.apiKey) {
      cstatForSession(sid, '请先在设置里填写 API Key、Base URL 和 Model。', 'error');
      setSettings(true);
      return;
    }
    if (p0.transport === 'openclaw' && !openClawEndpointFromCfg(cfg).ok) {
      cstatForSession(sid, 'OpenClaw：请在「Gateway Token」填写 token，或将带 #token= 的完整控制台地址填入 Base URL。', 'error');
      setSettings(true);
      return;
    }
    add('user', text);
    input.value = '';
    setSessionSending(sid, true);
    cstatForSession(sid, '正在请求模型响应...');
    var streamDraftId = '';
    var streamHasText = false;
    try {
      var p = P[cfg.provider] || P.openai,
        content = '';
      if (p.transport === 'anthropic') content = await reqClaude(cfg);
      else if (p.transport === 'gemini') content = await reqGemini(cfg);
      else if (p.transport === 'openclaw')
        content = await reqOpenClaw(cfg, {
          onProgress: function (textNow) {
            var sAct = sessionById(sid);
            if (!sAct) return;
            var draft = streamDraftId
              ? { _id: streamDraftId }
              : ensureAssistantDraft(sAct, String(textNow || '').trim() || '思考中...');
            if (draft && draft._id) streamDraftId = draft._id;
            if (streamDraftId) {
              var shown = String(textNow || '').trim() || '思考中...';
              streamHasText = !!String(textNow || '').trim();
              updateHistoryMessageById(sAct, streamDraftId, shown, false);
              if (state.activeSessionId === sid) scrollMsgsToLatest();
            }
          }
        });
      else content = await reqOpenAI(cfg);
      if (streamDraftId) {
        var sAct2 = sessionById(sid);
        if (sAct2) {
          updateHistoryMessageById(sAct2, streamDraftId, content, true);
          for (var di = sAct2.history.length - 1; di >= 0; di--) {
            if (sAct2.history[di] && sAct2.history[di]._id === streamDraftId) {
              sAct2.history[di]._draft = false;
              break;
            }
          }
          persistSessions();
          pushSessionHistoryToStore(sAct2);
          renderSessionTabs();
        }
      } else add('assistant', content);
      cstatForSession(sid, '响应完成。', 'success');
    } catch (err) {
      if (streamDraftId) {
        var sErr = sessionById(sid);
        if (sErr && !streamHasText) removeHistoryMessageById(sErr, streamDraftId, true);
        else if (sErr && streamHasText) {
          for (var ei = sErr.history.length - 1; ei >= 0; ei--) {
            if (sErr.history[ei] && sErr.history[ei]._id === streamDraftId) {
              sErr.history[ei]._draft = false;
              break;
            }
          }
          persistSessions();
          pushSessionHistoryToStore(sErr);
          renderSessionTabs();
        }
      }
      cstatForSession(sid, '请求失败：' + (err && err.message ? err.message : '未知错误'), 'error');
    } finally {
      setSessionSending(sid, false);
    }
  }

  var suppressClickUntil = 0;
  var screenshotLastClick = 0;
  function shouldSuppressClick() {
    return Date.now() < suppressClickUntil;
  }

  document.getElementById('app').addEventListener('click', function (e) {
    if (shouldSuppressClick()) {
      e.preventDefault();
      e.stopPropagation();
      return;
    }
    var b = e.target.closest('.tb');
    if (!b) return;
    e.stopPropagation();
    var cid = b.dataset.cmdId;
    if (cid) {
      cid = String(cid);
      if (cid === 'ch_t') {
        if (Date.now() - screenshotLastClick < 2000) return;
        screenshotLastClick = Date.now();
      }
      sel(cid);
      post({ type: 'toolbar_cmd', cmdId: cid });
      return;
    }
    var a = b.dataset.action;
    if (!a) return;
    a = String(a);
    if (a === 'Screenshot') {
      if (Date.now() - screenshotLastClick < 2000) return;
      screenshotLastClick = Date.now();
    }
    sel(a);
    post({ type: 'toolbar_toggle_action', action: a });
  });

  document.querySelectorAll('[data-logo-toggle]').forEach(function (el) {
    el.addEventListener('click', function (e) {
      if (shouldSuppressClick()) {
        e.preventDefault();
        e.stopPropagation();
        return;
      }
      e.stopPropagation();
      if (state.compact) {
        post({ type: 'exit_compact' });
        return;
      }
      setDrawer(!state.drawer);
    });
  });

  dclose.addEventListener('click', function () {
    setDrawer(false);
  });

  chatSet.addEventListener('click', function () {
    provider.dataset.prevProv = provider.value;
    setSettings(true);
  });

  if (chatSearch) {
    chatSearch.addEventListener('click', function () {
      runChatSearchPrompt();
    });
  }

  if (chatExportMd) chatExportMd.addEventListener('click', exportMarkdown);
  if (chatExportJson) chatExportJson.addEventListener('click', exportJson);
  if (debugToggle && debugPanel) {
    debugToggle.addEventListener('click', function () {
      var open = !debugPanel.classList.contains('open');
      debugPanel.classList.toggle('open', open);
      if (open) post({ type: 'niuma_debug_pull_go' });
    });
  }

  if (promptTplApply) promptTplApply.addEventListener('click', applySelectedPromptBuiltin);
  if (promptImportBtn && promptImportFile) {
    promptImportBtn.addEventListener('click', function () {
      promptImportFile.click();
    });
  }
  if (promptImportFile) {
    promptImportFile.addEventListener('change', function () {
      var f = this.files && this.files[0];
      if (!f) return;
      var rd = new FileReader();
      rd.onload = function () {
        systemPrompt.value = String(rd.result || '');
        saveCfg(false);
        sstat('已从文件导入：' + f.name, 'success');
      };
      rd.onerror = function () {
        sstat('读取文件失败。', 'error');
      };
      rd.readAsText(f);
      this.value = '';
    });
  }

  if (newSessionPickBg) newSessionPickBg.addEventListener('click', closeNewSessionPick);
  if (newSessionPickClose) newSessionPickClose.addEventListener('click', closeNewSessionPick);
  if (newSessionPick) {
    newSessionPick.addEventListener('click', function (e) {
      var item = e.target.closest('.ns-item');
      if (item && item.dataset.pickProvider) createSessionWithProvider(item.dataset.pickProvider);
    });
  }

  if (sessionTabsEl) {
    sessionTabsEl.addEventListener('click', function (e) {
      var xbtn = e.target.closest('[data-close-session]');
      if (xbtn) {
        e.stopPropagation();
        removeSession(xbtn.getAttribute('data-close-session'));
        return;
      }
      if (e.target.id === 'sessionTabAdd' || e.target.closest('#sessionTabAdd')) {
        openNewSessionPick();
        return;
      }
      var stab = e.target.closest('.stab');
      if (stab && stab.dataset.sessionId) switchSession(stab.dataset.sessionId);
    });
  }

  backdrop.addEventListener('click', function (e) {
    if (e.target === backdrop) setDrawer(false);
  });

  stage.addEventListener('click', function (e) {
    if (e.target === stage) setDrawer(false);
  });

  sbg.addEventListener('click', function () {
    setSettings(false);
  });

  sclose.addEventListener('click', function () {
    setSettings(false);
  });

  ssave.addEventListener('click', function () {
    saveCfg(true);
    if (ttydShellCommand) {
      try {
        post({ type: 'niuma_save_ttyd_shell', shell: String(ttydShellCommand.value || '').trim() });
      } catch (e) {}
    }
    setSettings(false);
  });

  send.addEventListener('click', sendChat);

  input.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' && e.ctrlKey) {
      e.preventDefault();
      sendChat();
    }
  });

  var cliOpenBtn = $('cliOpenBtn');
  var cliRestartBtn = $('cliRestartBtn');
  var cliReloadBtn = $('cliReloadBtn');
  var cliPopBtn = $('cliPopBtn');
  if (cliOpenBtn) {
    cliOpenBtn.addEventListener('click', function () {
      var s = activeSession();
      if (!s || !isCliSession(s)) return;
      var u = cliUrlForSession(s);
      if (u) applyCliFrameUrl(u);
      cstatForSession(s.id, '正在连接本机终端…');
      throttledNiumaCliOpen(true);
    });
  }
  if (cliReloadBtn) {
    cliReloadBtn.addEventListener('click', function () {
      var s = activeSession();
      var fr = $('cliFrame');
      if (!fr) return;
      try {
        var u = s && isCliSession(s) ? cliUrlForSession(s) : '';
        fr.src = u || fr.dataset.src || fr.src || 'about:blank';
      } catch (e) {}
    });
  }
  if (cliRestartBtn) {
    cliRestartBtn.addEventListener('click', function () {
      var s = activeSession();
      if (!s || !isCliSession(s)) return;
      cstatForSession(s.id, '正在重启 ttyd…');
      try {
        post({ type: 'niuma_cli_restart', engine: s.provider });
      } catch (e) {}
    });
  }
  if (cliPopBtn) {
    cliPopBtn.addEventListener('click', function () {
      var s = activeSession();
      if (!s || !isCliSession(s)) return;
      cstatForSession(s.id, '正在调用系统浏览器打开终端…');
      try {
        post({ type: 'niuma_cli_open_external', engine: s.provider });
      } catch (e) {}
    });
  }

  provider.addEventListener('focus', function () {
    this.dataset.prevProv = this.value;
  });

  provider.addEventListener('change', function () {
    var prev = normalizeProviderId(this.dataset.prevProv);
    if (prev && P[prev]) {
      if (!state.apiKeys) state.apiKeys = {};
      state.apiKeys[prev] = apiKey.value.trim();
    }
    var nextPid = normalizeProviderId(provider.value);
    applyProvider(nextPid, false);
    apiKey.value = (state.apiKeys && state.apiKeys[nextPid]) || '';
    refreshApiKeyField(nextPid);
    this.dataset.prevProv = nextPid;
    syncSessionFromForm(activeSession());
    persistSessions();
    renderSessionTabs();
    saveCfg(false);
    closeProviderDd();
    ensureDynamicModelsForActiveProvider();
  });

  modelPreset.addEventListener('change', function () {
    if (modelPreset.value) {
      model.value = modelPreset.value;
    }
    syncModelDdUi();
    syncSessionFromForm(activeSession());
    persistSessions();
    renderSessionTabs();
    saveCfg(false);
  });

  if (providerDdBtn) {
    providerDdBtn.addEventListener('click', function (e) {
      e.stopPropagation();
      toggleProviderDd();
    });
  }
  if (modelDdBtn) {
    modelDdBtn.addEventListener('click', function (e) {
      e.stopPropagation();
      toggleModelDd();
    });
  }
  document.addEventListener('click', function (e) {
    if (e.target.closest && (e.target.closest('#providerDd') || e.target.closest('#modelDd'))) return;
    closeProviderDd();
    closeModelDd();
  });

  function handleGlobalEscape(e) {
    var k = e.key || '';
    if (k !== 'Escape' && k !== 'Esc' && String(k).toLowerCase() !== 'escape') return;
    if (state.nspick) {
      e.preventDefault();
      e.stopPropagation();
      closeNewSessionPick();
      return;
    }
    if (state.settings) {
      e.preventDefault();
      e.stopPropagation();
      closeProviderDd();
      closeModelDd();
      setSettings(false);
      return;
    }
    if (state.drawer) {
      e.preventDefault();
      e.stopPropagation();
      setDrawer(false);
    }
  }
  // 捕获阶段：焦点在对话输入框等处时，冒泡阶段可能收不到 Esc，仍能关闭 NiuMa Chat 抽屉
  function handleGlobalNiumaHotkeys(e) {
    if (!state.drawer) return;
    if (!e.ctrlKey || e.altKey || e.metaKey) return;
    var key = String(e.key || '').toLowerCase();
    var code = String(e.code || '');

    if (key === 'n') {
      e.preventDefault();
      e.stopPropagation();
      if (!state.nspick) openNewSessionPick();
      return;
    }

    // Ctrl+W 关闭当前标签（至少保留一个）
    if (key === 'w') {
      var sid = state.activeSessionId || '';
      if (sid) {
        e.preventDefault();
        e.stopPropagation();
        removeSession(sid);
      }
      return;
    }

    // Ctrl+Delete 清空输入框
    if (key === 'delete' || code === 'Delete') {
      e.preventDefault();
      e.stopPropagation();
      if (input) {
        input.value = '';
        try {
          input.dispatchEvent(new Event('input', { bubbles: true }));
        } catch (_) {}
      }
      return;
    }

    // Ctrl+1..8 切换标签：优先 code（Digit1..Digit8 / Numpad1..Numpad8）
    var idx = -1;
    if (/^Digit[1-8]$/.test(code) || /^Numpad[1-8]$/.test(code)) {
      idx = parseInt(code.replace(/^\D+/, ''), 10) - 1;
    } else if (/^[1-8]$/.test(key)) {
      idx = parseInt(key, 10) - 1;
    }
    if (idx >= 0) {
      var tabs = Array.prototype.slice.call(document.querySelectorAll('#sessionTabs .stab[data-session-id]'));
      var target = tabs[idx];
      if (target && target.dataset && target.dataset.sessionId) {
        e.preventDefault();
        e.stopPropagation();
        switchSession(target.dataset.sessionId);
      }
      return;
    }
  }
  document.addEventListener('keydown', handleGlobalEscape, true);

  [apiKey, baseUrl, openclawSessionKey, model, systemPrompt, ttydShellCommand].forEach(function (el) {
    if (!el) return;
    el.addEventListener('input', function () {
      saveCfg(false);
    });
  });
  if (openclawSessionKey) {
    openclawSessionKey.addEventListener('blur', function () {
      openclawSessionKey.value = resolveOpenClawSessionKey(openclawSessionKey.value, '');
      saveCfg(false);
    });
  }
  if (openclawSessionPolicy) {
    openclawSessionPolicy.addEventListener('change', function () {
      if (openclawSessionPolicy.value === 'stable' && openclawSessionKey) {
        openclawSessionKey.value = 'agent:main:main';
      }
      saveCfg(false);
    });
  }

  resetCfg.addEventListener('click', reset);

  var dragT = 0;
  var DRAG_POST_INTERVAL_MS = 24;

  function dragHost() {
    var t = Date.now();
    if (t - dragT < DRAG_POST_INTERVAL_MS) return;
    dragT = t;
    post({ type: 'drag_host' });
  }

  var longPressTimer = 0;
  var longPressTriggered = false;
  var longPressPointerId = null;
  var longPressStartScreenX = 0;
  var longPressStartScreenY = 0;
  var LONG_PRESS_MS = 160;
  var LONG_PRESS_MOVE_PX = 8;
  var appEl = document.getElementById('app');

  function clearLongPressTimer() {
    if (longPressTimer) {
      clearTimeout(longPressTimer);
      longPressTimer = 0;
    }
  }

  function triggerLongPressDrag() {
    if (longPressTriggered) return;
    clearLongPressTimer();
    longPressTriggered = true;
    if (appEl && longPressPointerId != null && longPressPointerId !== -1 && appEl.setPointerCapture) {
      try {
        appEl.setPointerCapture(longPressPointerId);
      } catch (_) {}
    }
    dragHost();
  }

  function endLongPress(e) {
    clearLongPressTimer();
    if (longPressTriggered) {
      suppressClickUntil = Date.now() + 420;
    }
    if (appEl && e && e.pointerId != null && appEl.releasePointerCapture) {
      try {
        if (!appEl.hasPointerCapture || appEl.hasPointerCapture(e.pointerId)) {
          appEl.releasePointerCapture(e.pointerId);
        }
      } catch (_) {}
    }
    longPressTriggered = false;
    longPressPointerId = null;
  }

  function hostDragZoneOk(t) {
    if (!t || !t.closest) return false;
    if (t.closest('#resizeGrip')) return false;
    if (t.closest('#collapsedRoot')) return true;
    if (state.drawer) {
      if (t.closest('header.hdr') && !t.closest('header.hdr .ib')) return true;
      if (t.closest('.drawer-toolbar .logo-btn')) return true;
    }
    return false;
  }

  if (appEl) {
    appEl.addEventListener(
      'pointerdown',
      function (e) {
        if (e.button !== 0) return;
        if (state.settings || state.nspick) return;
        if (!hostDragZoneOk(e.target)) return;
        longPressTriggered = false;
        longPressPointerId = e.pointerId;
        longPressStartScreenX = e.screenX;
        longPressStartScreenY = e.screenY;
        clearLongPressTimer();
        longPressTimer = setTimeout(function () {
          if (longPressPointerId === null) return;
          triggerLongPressDrag();
        }, LONG_PRESS_MS);
      },
      true
    );
    appEl.addEventListener(
      'mousedown',
      function (e) {
        if (e.button !== 0) return;
        if (state.settings || state.nspick) return;
        if (longPressPointerId !== null) return;
        if (!hostDragZoneOk(e.target)) return;
        longPressTriggered = false;
        longPressPointerId = -1;
        longPressStartScreenX = e.screenX;
        longPressStartScreenY = e.screenY;
        clearLongPressTimer();
        longPressTimer = setTimeout(function () {
          if (longPressPointerId === null) return;
          triggerLongPressDrag();
        }, LONG_PRESS_MS);
      },
      true
    );

    appEl.addEventListener(
      'pointermove',
      function (e) {
        if (longPressPointerId === null) return;
        if (longPressPointerId !== -1 && e.pointerId !== longPressPointerId) return;
        if (longPressTriggered) return;
        if ((e.buttons & 1) === 0) {
          endLongPress(e);
          return;
        }
        var dx = e.screenX - longPressStartScreenX;
        var dy = e.screenY - longPressStartScreenY;
        if (dx * dx + dy * dy >= LONG_PRESS_MOVE_PX * LONG_PRESS_MOVE_PX) {
          triggerLongPressDrag();
        }
      },
      true
    );

    appEl.addEventListener(
      'pointerup',
      function (e) {
        if (longPressPointerId === null) return;
        if (longPressPointerId === -1) return;
        if (e.pointerId === longPressPointerId) endLongPress(e);
      },
      true
    );

    appEl.addEventListener(
      'pointercancel',
      function (e) {
        if (longPressPointerId === null) return;
        if (longPressPointerId === -1) return;
        if (e.pointerId === longPressPointerId) endLongPress(e);
      },
      true
    );

    appEl.addEventListener(
      'mousemove',
      function (e) {
        if (longPressPointerId !== -1) return;
        if (longPressTriggered) return;
        if ((e.buttons & 1) === 0) {
          endLongPress(e);
          return;
        }
        var dx = e.screenX - longPressStartScreenX;
        var dy = e.screenY - longPressStartScreenY;
        if (dx * dx + dy * dy >= LONG_PRESS_MOVE_PX * LONG_PRESS_MOVE_PX) {
          triggerLongPressDrag();
        }
      },
      true
    );
    appEl.addEventListener(
      'mouseup',
      function (e) {
        if (longPressPointerId !== -1) return;
        if (e.button === 0) endLongPress(e);
      },
      true
    );
  }

  collapsedRoot.addEventListener(
    'wheel',
    function (e) {
      e.preventDefault();
      post({ type: 'wheel', delta: e.deltaY > 0 ? -1 : 1 });
    },
    { passive: false }
  );

  function openHostContextMenuFromEvent(e) {
    if (!e) return;
    var tb = e.target && e.target.closest ? e.target.closest('.tb[data-cmd-id]') : null;
    if (tb) {
      var cid = String(tb.getAttribute('data-cmd-id') || '').trim();
      if (cid === 'ftb_cursor_menu') {
        e.preventDefault();
        e.stopPropagation();
        post({ type: 'toolbar_cmd_context', cmdId: cid, x: e.screenX, y: e.screenY });
        return;
      }
    }
    e.preventDefault();
    e.stopPropagation();
    post({ type: 'context_menu', x: e.screenX, y: e.screenY });
  }

  /* 右键菜单在折叠态/抽屉态都可触发（之前只绑定 collapsedRoot，打开 niuma chat 后会失效） */
  var appRoot = $('app');
  if (appRoot) {
    appRoot.addEventListener('contextmenu', openHostContextMenuFromEvent, true);
    appRoot.addEventListener(
      'pointerup',
      function (e) {
        if (e && e.button === 2) {
          post({ type: 'context_menu', x: e.screenX || 0, y: e.screenY || 0 });
        }
      },
      true
    );
  }

  var hdr = document.querySelector('.hdr');

  async function readDrop(dt) {
    if (!dt) return '';
    try {
      if (dt.items && dt.items.length) {
        for (var i = 0; i < dt.items.length; i++) {
          var it = dt.items[i];
          if (it.kind !== 'string') continue;
          var s = await new Promise(function (res) {
            try {
              it.getAsString(function (x) {
                res(x || '');
              });
            } catch (e2) {
              res('');
            }
          });
          if (s && String(s).trim()) return String(s).trim();
        }
      }
      return (dt.getData('text/plain') || dt.getData('Text') || dt.getData('text/uri-list') || '').trim();
    } catch (e) {
      return '';
    }
  }

  function findDropActionTarget(e) {
    var n = e && e.target ? e.target.closest('.tb') : null;
    if (n && n.getAttribute) {
      var b = n.getAttribute('data-drop-bucket');
      if (b) return b;
      return n.getAttribute('data-action') || 'Search';
    }
    return 'Search';
  }

  async function onDrop(e) {
    e.preventDefault();
    e.stopPropagation();
    var action = findDropActionTarget(e);
    tbEls().forEach(function (el) { el.classList.remove('drag-over'); });
    var t = await readDrop(e.dataTransfer);
    if (!t && e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files.length) t = (e.dataTransfer.files[0].name || '').trim();
    if (!t) return;
    loading(true);
    post({ type: 'drop_action', action: action, text: t });
  }

  function onDragOver(e) {
    e.preventDefault();
    e.stopPropagation();
    try {
      if (e.dataTransfer) e.dataTransfer.dropEffect = 'copy';
    } catch (e2) {}
    var action = findDropActionTarget(e);
    tbEls().forEach(function (el) {
      var da = el.getAttribute('data-drop-bucket') || el.getAttribute('data-action') || '';
      el.classList.toggle('drag-over', da === action);
    });
    if (String(action || '').toLowerCase() === 'search') dragOver(true);
  }

  function onDragLeave(e) {
    var rt = e.relatedTarget,
      ok = false;
    if (rt)
      searchEls().forEach(function (s) {
        if (s.contains(rt)) ok = true;
      });
    if (!ok) {
      dragOver(false);
      tbEls().forEach(function (el) { el.classList.remove('drag-over'); });
    }
  }

  function bindSearchDnD() {
    tbEls().forEach(function (search) {
      search.addEventListener('dragenter', function (e) {
        e.preventDefault();
      });
      search.addEventListener('dragover', onDragOver);
      search.addEventListener('dragleave', onDragLeave);
      search.addEventListener('drop', onDrop);
    });
  }

  rebuildToolbarButtons(state.toolbarActions);
  /* 兜底：仅当 set_logo 长时间未回调时显示，避免永远空白 */
  scheduleToolbarReveal(1200);

  document.body.addEventListener('dragover', function (e) {
    e.preventDefault();
  });

  document.body.addEventListener('drop', function (e) {
    e.preventDefault();
    var onS = false;
    tbEls().forEach(function (s) {
      if (e.target === s || s.contains(e.target)) onS = true;
    });
    if (onS) return;
    onDrop(e);
  });

  if (window.chrome && window.chrome.webview) {
    window.chrome.webview.addEventListener('message', function (ev) {
      var d = ev.data;
      if (typeof d === 'string') {
        try {
          d = JSON.parse(d);
        } catch (_) {}
      }
      if (d && d.type) dbg('R', d.type, 'ok');
      if (!d || !d.type) return;
      if (d.type === 'RESET_STATE') {
        try {
          if (typeof window.onWebViewResetState === 'function') window.onWebViewResetState();
        } catch (_) {}
        return;
      }
      if (d.type === 'ftb_debug') {
        dbg('H', d.msg || '', d.level === 'err' ? 'err' : 'ok');
        return;
      }
      if (d.type === 'niuma_debug_go_snapshot') {
        if (debugTrace) {
          debugTrace.lastGoSnapshotAt = new Date().toLocaleTimeString();
          dbgPush('prepare', 'go.snapshot', d.data || {}, true);
        }
        return;
      }
      if (d.type === 'SELECTION_CHANGE') {
        pulse(true);
        return;
      }
      if (d.type === 'SELECTION_CLEAR') {
        pulse(false);
        return;
      }
      if (d.type === 'drop_done') {
        loading(false);
        pulse(false);
        return;
      }
      if (d.type === 'set_scale') {
        scale(d.scale || 1);
        setCompact(!!d.compact);
        return;
      }
      if (d.type === 'set_toolbar_config') {
        rebuildToolbarButtons(d.actions || DEFAULT_TOOLBAR_ACTIONS);
        return;
      }
      if (d.type === 'set_toolbar_cmds') {
        rebuildToolbarCmdButtons(d.items || []);
        return;
      }
      if (d.type === 'set_logo') {
        var u = d.url || '';
        var imgs = Array.prototype.slice.call(document.querySelectorAll('.logo-btn .logo-img'));
        function paintThenReveal() {
          requestAnimationFrame(function () {
            requestAnimationFrame(revealToolbarSync);
          });
        }
        if (!u || !imgs.length) {
          paintThenReveal();
          return;
        }
        var remain = imgs.length;
        imgs.forEach(function (im) {
          var done = false;
          function once() {
            if (done) return;
            done = true;
            if (im.naturalWidth && im.naturalHeight) im.classList.add('logo-ready');
            remain--;
            if (remain <= 0) paintThenReveal();
          }
          im.classList.remove('logo-ready');
          im.onload = once;
          im.onerror = once;
          im.src = u;
          if (im.decode) {
            im.decode().then(once).catch(once);
          } else if (im.complete) {
            once();
          }
        });
        return;
      }
      if (d.type === 'set_theme') {
        applyTheme(d.themeMode || d.theme);
        return;
      }
      if (d.type === 'set_selected') sel(d.action || '');
      if (d.type === 'ttyd_ready') {
        var turl = String(d.baseUrl || '').trim();
        var ts = activeSession();
        if (!ts || !isCliSession(ts)) return;
        if (_niumaPendingPop && turl) {
          _niumaPendingPop = false;
          try {
            window.open(turl, '_blank');
          } catch (e) {}
          cstatForSession(ts.id, '已在外部浏览器打开终端。', 'success');
          return;
        }
        if (turl) {
          ts.baseUrl = String(turl).replace(/\/+$/, '');
          persistSessions();
        }
        turl = turl || cliUrlForSession(ts);
        if (turl) applyCliFrameUrl(turl);
        cstatForSession(ts.id, '本机终端已就绪。', 'success');
        return;
      }
      if (d.type === 'ttyd_error') {
        var ts2 = activeSession();
        cstatForSession(
          ts2 && ts2.id,
          'ttyd：' + (d.message || '启动失败，请检查同目录下是否有 ttyd.exe 或点「重试/重启」'),
          'error'
        );
        return;
      }
      if (d.type === 'niuma_compose_send') {
        var inText = String(d.text || '');
        if (!inText.trim()) return;
        var appendMode = d.append !== false;
        var shouldOpenDrawer = d.openDrawer !== false;
        var shouldSendNow = d.send !== false;
        if (shouldOpenDrawer) setDrawer(true);
        var base = String(input.value || '');
        if (appendMode && base.trim()) input.value = base.replace(/\s+$/, '') + '\n\n' + inText;
        else input.value = inText;
        try {
          input.dispatchEvent(new Event('input', { bubbles: true }));
        } catch (_) {}
        requestAnimationFrame(function () {
          try {
            input.focus();
            var end = input.value.length;
            input.setSelectionRange(end, end);
          } catch (_) {}
          if (shouldSendNow) sendChat();
        });
        return;
      }
      if (d.type === 'host_force_toolbar_home') {
        setSettings(false);
        setNspick(false);
        if (state.drawer) setDrawer(false);
        else {
          state.drawer = false;
          document.body.classList.remove('drawer-open');
          if (stage) stage.setAttribute('aria-hidden', 'true');
          if (panel) panel.setAttribute('aria-hidden', 'true');
        }
        return;
      }
    });
  }

  var rz = false,
    rzX = 0,
    rzW = 0;
  if (resizeGrip) {
    resizeGrip.addEventListener('pointerdown', function (e) {
      if (e.button !== 0) return;
      rz = true;
      rzX = e.clientX;
      rzW = document.documentElement.clientWidth;
      try {
        resizeGrip.setPointerCapture(e.pointerId);
      } catch (x) {}
    });
    resizeGrip.addEventListener('pointermove', function (e) {
      if (!rz) return;
      var b = drawerResizeBoundsPx();
      var nw = Math.max(b.min, Math.min(b.max, rzW + (rzX - e.clientX)));
      post({ type: 'drawer_resize', width: nw });
    });
    resizeGrip.addEventListener('pointerup', function (e) {
      if (rz) {
        rz = false;
        post({ type: 'drawer_resize_done' });
        try {
          resizeGrip.releasePointerCapture(e.pointerId);
        } catch (x) {}
      }
    });
    resizeGrip.addEventListener('pointercancel', function () {
      if (rz) {
        rz = false;
        post({ type: 'drawer_resize_done' });
      }
    });
  }

  fillProviders();
  fillPromptBuiltinSelect();
  loadCfg();
  applyTheme(state.themeMode);
  scale(1);
  setCompact(false);
  post({ type: 'toolbar_ready' });
  setTimeout(function () {
    post({ type: 'UI_FINISHED' });
  }, 180);
  requestAnimationFrame(function () {
    requestAnimationFrame(function () {
      setTimeout(function () {
        post({ type: 'UI_FINISHED' });
      }, 16);
    });
  });
})();

