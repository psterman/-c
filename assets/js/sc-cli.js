/* SearchCenter cli chunk — lazy-loaded via ScChunkLoader */
(function initScCliRuntimeConstants() {
  const g = typeof globalThis !== "undefined" ? globalThis : window;
  if (g.SC_ACTIVE_CLI_ENGINE_KEY == null) g.SC_ACTIVE_CLI_ENGINE_KEY = "sc_active_cli_engine_v1";
  if (g.SC_CLI_OPEN_THROTTLE_MS == null) g.SC_CLI_OPEN_THROTTLE_MS = 1200;
  if (g.SC_CLI_READY_TTL_MS == null) g.SC_CLI_READY_TTL_MS = 300000;
})();
function scCliActiveEngineKey() {
  return globalThis.SC_ACTIVE_CLI_ENGINE_KEY || "sc_active_cli_engine_v1";
}
function scCliOpenThrottleMs() {
  return Number(globalThis.SC_CLI_OPEN_THROTTLE_MS) || 1200;
}
function scCliReadyTtlMs() {
  return Number(globalThis.SC_CLI_READY_TTL_MS) || 300000;
}
const SC_CLI_PORTS = {
  codex_cli: 7681,
  gemini_cli: 7682,
  openclaw_cli: 7683,
  qwen_cli: 7684,
  ollama_cli: 7685,
  claude_cli: 7686,
  deepseek_cli: 7687,
  kimi_cli: 7688,
  zhipu_cli: 7689,
  copilot_cli: 7690
};
const SC_CLI_ENGINE_ORDER = [
  "codex_cli", "gemini_cli", "openclaw_cli", "qwen_cli", "ollama_cli",
  "claude_cli", "deepseek_cli", "kimi_cli", "zhipu_cli", "copilot_cli"
];
const SC_CLI_ENGINE_ROLE = {
  codex_cli: "Codex 终端",
  gemini_cli: "Gemini CLI",
  openclaw_cli: "OpenClaw",
  qwen_cli: "通义千问",
  ollama_cli: "本地模型",
  claude_cli: "Claude CLI",
  deepseek_cli: "DeepSeek",
  kimi_cli: "Kimi CLI",
  zhipu_cli: "智谱 CLI",
  copilot_cli: "Copilot CLI"
};
function cliEngineRoleLabel(engineId) {
  const id = normalizeCliEngineId(engineId);
  return SC_CLI_ENGINE_ROLE[id] || id.replace(/_cli$/, "");
}
function isCliSidebarNav() {
  return !!document.getElementById("cli-engine-sidebar");
}
/** 联网引擎 value → ttyd 引擎 id（避免 deepseek 误落到 7681 codex） */
const SC_WEB_TO_CLI_ENGINE = {
  codex: "codex_cli",
  chatgpt: "codex_cli",
  gemini: "gemini_cli",
  openclaw: "openclaw_cli",
  qwen: "qwen_cli",
  qianwen: "qwen_cli",
  ollama: "ollama_cli",
  claude: "claude_cli",
  deepseek: "deepseek_cli",
  kimi: "kimi_cli",
  zhipu: "zhipu_cli",
  copilot: "copilot_cli"
};
function normalizeCliEngineId(v) {
  const s = String(v || "").trim().toLowerCase();
  if (!s) return "codex_cli";
  if (Object.prototype.hasOwnProperty.call(SC_CLI_PORTS, s)) return s;
  if (SC_WEB_TO_CLI_ENGINE[s]) return SC_WEB_TO_CLI_ENGINE[s];
  if (s.endsWith("_cli")) {
    const bare = s.slice(0, -4);
    if (SC_WEB_TO_CLI_ENGINE[bare]) return SC_WEB_TO_CLI_ENGINE[bare];
  }
  return s;
}

function isKnownCliEngineId(v) {
  const id = normalizeCliEngineId(v);
  return Object.prototype.hasOwnProperty.call(SC_CLI_PORTS, id);
}

function getCliEnginesForTabs() {
  const rows = Array.isArray(state.engines) ? state.engines : [];
  const byId = new Map();
  rows.forEach((e) => {
    if (!e || !e.value) return;
    const id = normalizeCliEngineId(e.value);
    if (!SC_CLI_PORTS[id]) return;
    if (!byId.has(id)) byId.set(id, Object.assign({}, e, { value: id }));
  });
  // 固定全量引擎标签，避免后端偶发返回不全导致标签消失
  return SC_CLI_ENGINE_ORDER.map((id) => {
    const base = byId.get(id) || {};
    return Object.assign({
      value: id,
      name: id.replace(/_cli$/, "").replace(/^./, (c) => c.toUpperCase()),
      iconUrl: ""
    }, base, { value: id });
  });
}
const _cliOpenThrottleByEngine = new Map();
const _cliUrlByEngine = new Map(); // engineId -> 最近 ttyd_ready 的 URL（切标签可立即挂载）
const _cliAutoBootDone = new Set(); // 本会话是否已自动注入启动 CLI
/** ttyd 用轻量 cmd 时，iframe 就绪后自动注入的首条命令（与 codex 的 cmd /k 行为等价） */
const SC_CLI_AUTO_BOOT_CMD = {
  codex_cli: "codex",
  gemini_cli: "gemini",
  openclaw_cli: "openclaw",
  qwen_cli: "qwen",
  ollama_cli: "ollama",
  claude_cli: "claude",
  deepseek_cli: "deepseek",
  kimi_cli: "kimi",
  zhipu_cli: "chelper",
  copilot_cli: "copilot"
};
/** FinalShell 风格：终端下方快捷命令（点击即注入并回车） */
const SC_CLI_QUICK_CMDS_COMMON = [
  { label: "清屏", cmd: "cls" },
  { label: "当前目录", cmd: "cd" },
  { label: "列文件", cmd: "dir" },
  { label: "Git 状态", cmd: "git status" },
  { label: "查看 IP", cmd: "ipconfig" }
];
const SC_CLI_QUICK_PANEL_KEY = "sc_cli_quick_panel_v1";
let _cliSyncDebounceTimer = 0;
let _cliTerminalFocusLock = false;
let _cliFrameLoadedPort = 0;
const _cliFrameCache = new Map(); // engineId -> iframe（保活）
let _cliAutoRetryTimer = 0;
const _cliAutoRetryCountByEngine = new Map();
let _cliConnectFallbackTimer = 0;
let _cliLoadingPollTimer = 0;
const _cliLoadingPollCountByEngine = new Map();
function sendComposeToCli() {
  const input = document.getElementById("search");
  const keyword = input ? String(input.value || "") : "";
  state.keyword = keyword;
  if (!keyword.trim()) {
    const st = document.getElementById("status");
    if (st) st.textContent = "请输入要发送的内容";
    return;
  }
  const eng = getActiveCliEngine();
  const ready = isCliEngineReady(eng) && cliFrameUrlLooksLiveForPort(cliPortForEngine(eng));
  if (!ready) {
    setCliLoadingVisible(true, "终端初始化中，请稍候…");
    throttledNiumaCliOpen(false);
  }
  postToAhk({ type: "cliSend", prompt: keyword, engine: eng });
  try {
    input.focus();
  } catch (_) {}
}
function cliPortForEngine(engine) {
  const k = normalizeCliEngineId(engine);
  return SC_CLI_PORTS[k] || 7681;
}

function cliBaseUrlForEngine(engine) {
  return "http://127.0.0.1:" + cliPortForEngine(engine) + "/";
}

function cliThemePayload() {
  const light = String(document.documentElement.getAttribute("data-theme") || "").toLowerCase() === "light";
  return light
    ? {
        scrollbarSliderBackground: "rgba(214,111,26,0.36)",
        scrollbarSliderHoverBackground: "rgba(211,84,0,0.56)",
        scrollbarSliderActiveBackground: "rgba(211,84,0,0.72)"
      }
    : {
        scrollbarSliderBackground: "rgba(255,120,48,0.4)",
        scrollbarSliderHoverBackground: "rgba(255,132,64,0.6)",
        scrollbarSliderActiveBackground: "rgba(255,150,80,0.76)"
      };
}

function cliUrlWithTheme(rawUrl) {
  const u = String(rawUrl || "").trim();
  if (!u) return "";
  try {
    const obj = new URL(u, window.location.href);
    obj.searchParams.set("theme", JSON.stringify(cliThemePayload()));
    return obj.toString();
  } catch (_) {
    return u;
  }
}

function getActiveCliEngine() {
  const engines = getCliEnginesForTabs();
  const active = normalizeCliEngineId(state.activeCliEngine);
  if (active && engines.some((e) => e && e.value === active)) return active;
  const sel = Array.isArray(state.selectedEngines) ? state.selectedEngines : [];
  for (let i = 0; i < sel.length; i++) {
    const id = normalizeCliEngineId(sel[i]);
    if (engines.some((e) => e && e.value === id)) return id;
  }
  if (engines.length && engines[0].value) return String(engines[0].value);
  return "codex_cli";
}

/** 焦点在 ttyd iframe 或终端区域时，勿拦截 Enter/Space/Esc，交给 xterm */
function isCliTerminalInputTarget() {
  if (getUIMode() !== "cli") return false;
  if (_cliTerminalFocusLock) return true;
  const ae = document.activeElement;
  if (!ae) return false;
  if (ae.id === "cliFrame") return true;
  if (ae.classList && ae.classList.contains("cli-frame")) return true;
  if (ae.closest && ae.closest(".cli-frame-stack")) return true;
  return false;
}

function setCliTerminalFocusLock(on) {
  _cliTerminalFocusLock = !!on;
  try {
    postToAhk({ type: "cliTerminalFocus", active: _cliTerminalFocusLock });
  } catch (_) {}
}

function shouldYieldKeysToCliTerminal(event) {
  if (getUIMode() !== "cli") return false;
  const ae = document.activeElement;
  const tag = ae ? ae.tagName : "";
  const searchFocused = ae && ae.id === "search";
  if (searchFocused) return false;
  if (_cliTerminalFocusLock || isCliTerminalInputTarget()) return true;
  const k = String(event.key || "");
  if (k === "Enter") return true;
  if (k === "Escape") return false; // ESC 交给宿主关闭搜索中心，避免关闭后状态悬挂
  if (k !== " ") return false;
  if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT" || tag === "BUTTON") return false;
  if (!ae || ae === document.body || ae === document.documentElement) return true;
  return false;
}

function focusCliTerminalFrame() {
  const fr = getActiveCliFrameEl();
  if (!fr) return;
  try { fr.focus(); } catch (_) {}
}

function getCliFrameStackEl() {
  return document.getElementById("cli-frame-stack");
}

function getActiveCliFrameEl() {
  return getCliFrameElForEngine(getActiveCliEngine());
}

function getCliFrameElForEngine(engine) {
  const k = normalizeCliEngineId(engine);
  if (!k) return null;
  if (_cliFrameCache.has(k)) return _cliFrameCache.get(k);
  return null;
}

function ensureCliFrameForEngine(engine) {
  const k = normalizeCliEngineId(engine);
  if (!k) return null;
  const stack = getCliFrameStackEl();
  if (!stack) return null;
  if (_cliFrameCache.has(k)) return _cliFrameCache.get(k);
  const legacy = document.getElementById("cliFrame");
  if (legacy && !_cliFrameCache.size) {
    legacy.id = "cliFrame_" + k;
    legacy.dataset.engine = k;
    legacy.title = "CLI ttyd 终端 - " + k;
    _cliFrameCache.set(k, legacy);
    return legacy;
  }
  const fr = document.createElement("iframe");
  fr.className = "cli-frame";
  fr.id = "cliFrame_" + k;
  fr.dataset.engine = k;
  fr.src = "about:blank";
  fr.title = "CLI ttyd 终端 - " + k;
  fr.setAttribute("tabindex", "0");
  fr.style.display = "none";
  fr.style.opacity = "0";
  fr.style.pointerEvents = "none";
  fr.addEventListener("load", () => {
    if (normalizeCliEngineId(getActiveCliEngine()) !== k) return;
    const cur = String(fr.src || "");
    if (cur && cur.indexOf("about:blank") !== 0) setCliLoadingVisible(false);
  });
  stack.appendChild(fr);
  _cliFrameCache.set(k, fr);
  return fr;
}

function setActiveCliFrame(engine) {
  const active = normalizeCliEngineId(engine);
  _cliFrameCache.forEach((fr, k) => {
    const on = (k === active);
    fr.style.display = on ? "block" : "none";
    fr.style.opacity = on ? "1" : "0";
    fr.style.pointerEvents = on ? "auto" : "none";
  });
}

function stopCliLoadingPoll() {
  if (_cliLoadingPollTimer) {
    clearInterval(_cliLoadingPollTimer);
    _cliLoadingPollTimer = 0;
  }
}

function startCliLoadingPoll() {
  stopCliLoadingPoll();
  const engine = normalizeCliEngineId(getActiveCliEngine());
  _cliLoadingPollCountByEngine.set(engine, 0);
  _cliLoadingPollTimer = setInterval(() => {
    const el = document.getElementById("cliLoading");
    if (!el || el.classList.contains("hidden") || getUIMode() !== "cli") {
      stopCliLoadingPoll();
      return;
    }
    const active = normalizeCliEngineId(getActiveCliEngine());
    if (active !== engine) {
      stopCliLoadingPoll();
      return;
    }
    const n = Number(_cliLoadingPollCountByEngine.get(engine) || 0) + 1;
    _cliLoadingPollCountByEngine.set(engine, n);
    // 轮询期间持续轻量请求 open，避免首个 open 丢失后永久卡住
    throttledNiumaCliOpen(false);
    // 约 6 秒仍未就绪时自动重启一次该引擎
    if (n === 5) {
      postToAhk({
        type: "niuma_cli_restart",
        engine,
        baseUrl: cliBaseUrlForEngine(engine),
        reqId: "sc_poll_r_" + Date.now()
      });
    }
    syncCliWorkspace(false);
  }, 450);
}

function setCliLoadingVisible(on, msg) {
  const el = document.getElementById("cliLoading");
  if (!el) return;
  el.classList.toggle("hidden", !on);
  if (msg) el.textContent = msg;
  if (on) startCliLoadingPoll();
  else stopCliLoadingPoll();
  if (!on && _cliAutoRetryTimer) {
    clearTimeout(_cliAutoRetryTimer);
    _cliAutoRetryTimer = 0;
  }
}

function cliFrameCurrentPort() {
  const fr = getActiveCliFrameEl();
  if (!fr) return 0;
  try {
    return parseInt(new URL(String(fr.src || ""), "http://127.0.0.1/").port, 10) || 0;
  } catch (_) {
    return _cliFrameLoadedPort || 0;
  }
}

function cliFrameElForPort(port) {
  port = Number(port) || 0;
  if (!port) return null;
  for (const eng of Object.keys(SC_CLI_PORTS)) {
    if (Number(SC_CLI_PORTS[eng]) === port) {
      const fr = getCliFrameElForEngine(eng);
      if (fr) return fr;
    }
  }
  return getActiveCliFrameEl();
}

function cliFrameUrlLooksLiveForPort(port) {
  port = Number(port) || 0;
  const fr = cliFrameElForPort(port);
  if (!fr || !port) return false;
  const u = String(fr.src || "").trim();
  if (!u || u === "about:blank") return false;
  try {
    return parseInt(new URL(u, "http://127.0.0.1/").port, 10) === port;
  } catch (_) {
    return _cliFrameLoadedPort === port;
  }
}

function cliUrlBaseKey(u) {
  try {
    const o = new URL(String(u || ""), "http://127.0.0.1/");
    return o.origin + o.pathname;
  } catch (_) {
    return String(u || "");
  }
}

function applyCliFrameUrl(u, engine) {
  u = String(u || "").trim();
  if (!u) return;
  const eng = normalizeCliEngineId(engine || getActiveCliEngine());
  const fr = ensureCliFrameForEngine(eng) || getCliFrameElForEngine(eng);
  if (!fr) return;
  if (eng) _cliUrlByEngine.set(eng, u);
  const cur = String(fr.src || "").trim();
  if (cur && cliUrlBaseKey(cur) === cliUrlBaseKey(u)) return;
  fr.src = u;
  try {
    _cliFrameLoadedPort = parseInt(new URL(u, "http://127.0.0.1/").port, 10) || 0;
  } catch (_) {}
}

function markCliEngineReady(engine) {
  const k = normalizeCliEngineId(engine);
  if (!k || !SC_CLI_PORTS[k]) return;
  if (!state.cliReadyEngines || typeof state.cliReadyEngines !== "object") state.cliReadyEngines = {};
  state.cliReadyEngines[k] = Date.now();
}

function clearCliEngineReady(engine) {
  const k = normalizeCliEngineId(engine);
  if (!k || !state.cliReadyEngines) return;
  delete state.cliReadyEngines[k];
}

function isCliEngineReady(engine) {
  const k = normalizeCliEngineId(engine);
  if (!k || !state.cliReadyEngines || typeof state.cliReadyEngines !== "object") return false;
  const t = Number(state.cliReadyEngines[k]) || 0;
  if (!t) return false;
  return Date.now() - t < scCliReadyTtlMs();
}

function scheduleSyncCliWorkspace(spawnIfNeeded) {
  if (_cliSyncDebounceTimer) clearTimeout(_cliSyncDebounceTimer);
  _cliSyncDebounceTimer = setTimeout(() => {
    _cliSyncDebounceTimer = 0;
    syncCliWorkspace(!!spawnIfNeeded);
  }, spawnIfNeeded ? 80 : 160);
}

function cliFrameUrlLooksLive() {
  return cliFrameUrlLooksLiveForPort(cliPortForEngine(getActiveCliEngine()));
}

function throttledNiumaCliOpen(force) {
  const now = Date.now();
  const engine = getActiveCliEngine();
  const last = Number(_cliOpenThrottleByEngine.get(engine) || 0);
  if (!force && now - last < scCliOpenThrottleMs()) return;
  _cliOpenThrottleByEngine.set(engine, now);
  postToAhk({ type: "niuma_cli_open", engine, reqId: "sc_" + now });
}

function resetCliOpenThrottle(engine) {
  const eng = normalizeCliEngineId(engine || getActiveCliEngine());
  _cliOpenThrottleByEngine.delete(eng);
}

function scheduleCliAutoBoot(engine, bootCmd) {
  const eng = normalizeCliEngineId(engine);
  const cmd = String(bootCmd || SC_CLI_AUTO_BOOT_CMD[eng] || "").trim();
  if (!cmd || _cliAutoBootDone.has(eng)) return;
  _cliAutoBootDone.add(eng);
  setTimeout(() => {
    if (normalizeCliEngineId(getActiveCliEngine()) !== eng) return;
    if (!isCliEngineReady(eng)) return;
    postToAhk({ type: "cliSend", prompt: cmd, engine: eng, autoBoot: true });
  }, 900);
}

function syncCliWorkspace(spawnIfNeeded) {
  if (getUIMode() !== "cli") return;
  if (state.hostMinimized) return;
  const engine = getActiveCliEngine();
  try { localStorage.setItem(scCliActiveEngineKey(), String(engine || "codex_cli")); } catch (_) {}
  ensureCliFrameForEngine(engine);
  setActiveCliFrame(engine);
  state.activeCliEngine = engine;
  const engRow = getCliEnginesForTabs().find((e) => e && e.value === engine);
  const titleEl = document.getElementById("cliTitle");
  const topStatus = document.getElementById("wb-topbar-status");
  const titleText = (engRow ? engRow.name : engine) + " · 端口 " + cliPortForEngine(engine);
  if (titleEl) titleEl.textContent = titleText;
  if (topStatus) topStatus.textContent = titleText;
  renderCliQuickCmds();
  const port = cliPortForEngine(engine);
  ensureCliFrameForEngine(engine);
  setActiveCliFrame(engine);
  const engineReady = isCliEngineReady(engine);
  const cachedUrl = _cliUrlByEngine.get(engine) || "";
  const mountUrl = cachedUrl || cliUrlWithTheme(cliBaseUrlForEngine(engine));
  const frameLive = engineReady && cliFrameUrlLooksLiveForPort(port);
  if (frameLive) {
    applyCliFrameUrl(mountUrl, engine);
    setCliLoadingVisible(false);
    if (_cliConnectFallbackTimer) {
      clearTimeout(_cliConnectFallbackTimer);
      _cliConnectFallbackTimer = 0;
    }
  } else if (engineReady && mountUrl) {
    // 后端已 ttyd_ready，但 iframe 尚未加载：挂载 URL，勿回到「正在连接」
    applyCliFrameUrl(mountUrl, engine);
    setCliLoadingVisible(true, "终端加载中…");
  } else {
    // 未就绪时保持 about:blank，避免出现“127.0.0.1 拒绝连接”错误页
    const fr = getCliFrameElForEngine(engine);
    if (fr) {
      const cur = String(fr.src || "");
      if (!cur || cur.indexOf("about:blank") !== 0) {
        try { fr.src = "about:blank"; } catch (_) {}
      }
    }
    setCliLoadingVisible(true, "正在连接 ttyd…");
    if (spawnIfNeeded) throttledNiumaCliOpen(false);
  }
  if ((_cliTerminalFocusLock || spawnIfNeeded) && !state.hostMinimized) {
    setTimeout(() => {
      focusCliTerminalFrame();
      setCliTerminalFocusLock(true);
    }, 0);
  }
}

function renderCliEngineTabs() {
  const sidebar = document.getElementById("cli-engine-sidebar");
  const horizontal = document.getElementById("cli-engine-tabs");
  const wrap = sidebar || horizontal;
  if (!wrap) return;
  if (getUIMode() !== "cli") {
    wrap.innerHTML = "";
    if (sidebar && horizontal && horizontal !== wrap) horizontal.innerHTML = "";
    return;
  }
  const vertical = isCliSidebarNav();
  const engines = getCliEnginesForTabs();
  const active = getActiveCliEngine();
  wrap.innerHTML = "";
  const countEl = document.getElementById("cli-engine-count");
  if (countEl) countEl.textContent = String(engines.length);
  engines.forEach((engine) => {
    if (!engine || !engine.value) return;
    const engId = normalizeCliEngineId(engine.value);
    const isActive = normalizeCliEngineId(engine.value) === normalizeCliEngineId(active);
    const ready = isCliEngineReady(engId);
    const port = cliPortForEngine(engId);
    const btn = document.createElement("button");
    btn.type = "button";
    btn.setAttribute("role", "tab");
    btn.setAttribute("aria-selected", isActive ? "true" : "false");
    btn.dataset.engine = String(engine.value);
    if (vertical) {
      btn.className = "sc-web-ai-row cli-nav-row" + (isActive ? " active" : "") + (ready ? " is-ready" : "");
      const iconHtml = engine.iconUrl
        ? "<img class=\"web-chip-icon\" src=\"" + escapeAttr(engine.iconUrl) + "\" alt=\"\">"
        : "<span class=\"web-chip-fallback\">" + escapeHtml(String(engine.name || engId).slice(0, 1).toUpperCase()) + "</span>";
      const taskText = ready
        ? (isActive ? "当前任务：终端就绪" : "当前任务：待命")
        : (isActive ? "当前任务：连接 ttyd…" : "当前任务：未连接");
      const progressPct = ready ? (isActive ? "100" : "0") : (isActive ? "45" : "0");
      btn.innerHTML =
        "<span class=\"sc-web-ai-row__icon\">" + iconHtml + "</span>" +
        "<span class=\"sc-web-ai-row__main\">" +
          "<span class=\"sc-web-ai-row__title\">" + escapeHtml((engine.name || engId) + " - " + cliEngineRoleLabel(engId)) + "</span>" +
          "<span class=\"sc-web-ai-row__sub\">" + escapeHtml(taskText) + (isActive && !ready ? " 45%" : (isActive && ready ? " 100%" : "")) + "</span>" +
          "<span class=\"sc-web-ai-row__progress\"><span class=\"sc-web-ai-row__progress-fill" + (isActive && !ready ? " is-indeterminate" : "") + "\" style=\"width:" + progressPct + "%\"></span></span>" +
        "</span>" +
        "<span class=\"sc-web-ai-row__dot" + (ready ? " dot-ready" : (isActive ? " dot-loading" : "")) + "\" aria-hidden=\"true\"></span>";
    } else {
      btn.className = "cli-etab" + (isActive ? " active" : "");
      const icon = engine.iconUrl
        ? "<img src=\"" + escapeAttr(engine.iconUrl) + "\" alt=\"\">"
        : "";
      btn.innerHTML = icon + "<span class=\"cli-etab-label\">" + escapeHtml(engine.name || engine.value) + "</span>";
    }
    btn.addEventListener("click", () => {
      const id = String(engine.value);
      if (normalizeCliEngineId(state.activeCliEngine) === normalizeCliEngineId(id)) return;
      setCliTerminalFocusLock(true);
      state.activeCliEngine = id;
      renderCliEngineTabs();
      syncCliWorkspace(true);
      renderCliQuickCmds();
    });
    wrap.appendChild(btn);
  });
}

function syncCliSidebarIndicator() {
  /* 纵向 sc-web-ai-row 模式用 active 高亮，无需滑动指示条 */
}

function getCliQuickCmdsForEngine(engine) {
  const eng = normalizeCliEngineId(engine);
  const cmds = [];
  const boot = String(SC_CLI_AUTO_BOOT_CMD[eng] || "").trim();
  if (boot) {
    const row = getCliEnginesForTabs().find((e) => e && e.value === eng);
    cmds.push({ label: (row && row.name) ? String(row.name) : boot, cmd: boot });
  }
  return cmds.concat(SC_CLI_QUICK_CMDS_COMMON);
}

function isCliQuickPanelOpen() {
  try {
    const v = localStorage.getItem(SC_CLI_QUICK_PANEL_KEY);
    if (v === "0") return false;
    if (v === "1") return true;
  } catch (_) {}
  return true;
}

function setCliQuickPanelOpen(open) {
  try { localStorage.setItem(SC_CLI_QUICK_PANEL_KEY, open ? "1" : "0"); } catch (_) {}
  renderCliQuickCmds();
}

function sendCliQuickCmd(cmd) {
  const text = String(cmd || "").trim();
  if (!text) return;
  const eng = getActiveCliEngine();
  const ready = isCliEngineReady(eng) && cliFrameUrlLooksLiveForPort(cliPortForEngine(eng));
  if (!ready) {
    setCliLoadingVisible(true, "终端初始化中，请稍候…");
    throttledNiumaCliOpen(false);
  }
  setCliTerminalFocusLock(true);
  postToAhk({ type: "cliSend", prompt: text, engine: eng });
  focusCliTerminalFrame();
}

function renderCliQuickCmds() {
  const wrap = document.getElementById("cliQuickCmds");
  const toggleBtn = document.getElementById("cliQuickToggleBtn");
  if (!wrap) return;
  if (getUIMode() !== "cli") {
    wrap.innerHTML = "";
    wrap.classList.add("hidden");
    return;
  }
  const open = isCliQuickPanelOpen();
  wrap.classList.toggle("hidden", !open);
  if (toggleBtn) toggleBtn.classList.toggle("primary", open);
  if (!open) {
    wrap.innerHTML = "";
    return;
  }
  const engine = getActiveCliEngine();
  const cmds = getCliQuickCmdsForEngine(engine);
  wrap.innerHTML = "";
  cmds.forEach((item) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "cli-qcmd";
    btn.title = item.cmd;
    btn.textContent = item.label;
    btn.addEventListener("click", () => sendCliQuickCmd(item.cmd));
    wrap.appendChild(btn);
  });
}

function initCliTerminalControls() {
  const workDirBtn = document.getElementById("cliWorkDirBtn");
  const pasteBtn = document.getElementById("cliPasteBtn");
  const interruptBtn = document.getElementById("cliInterruptBtn");
  const quickToggleBtn = document.getElementById("cliQuickToggleBtn");
  const popBtn = document.getElementById("cliPopBtn");
  if (workDirBtn) {
    workDirBtn.addEventListener("click", () => {
      const engine = getActiveCliEngine();
      postToAhk({ type: "niuma_cli_open_workdir", engine, reqId: "sc_wd_" + Date.now() });
    });
  }
  if (pasteBtn) {
    pasteBtn.addEventListener("click", () => {
      const engine = getActiveCliEngine();
      setCliTerminalFocusLock(true);
      postToAhk({ type: "cliPaste", engine });
      focusCliTerminalFrame();
    });
  }
  if (interruptBtn) {
    interruptBtn.addEventListener("click", () => {
      const engine = getActiveCliEngine();
      setCliTerminalFocusLock(true);
      postToAhk({ type: "cliInterrupt", engine });
      focusCliTerminalFrame();
    });
  }
  if (quickToggleBtn) {
    quickToggleBtn.addEventListener("click", () => {
      setCliQuickPanelOpen(!isCliQuickPanelOpen());
    });
  }
  if (popBtn) {
    popBtn.addEventListener("click", () => {
      const engine = getActiveCliEngine();
      postToAhk({
        type: "niuma_cli_open_external",
        engine,
        baseUrl: cliUrlWithTheme(cliBaseUrlForEngine(engine)),
        reqId: "sc_x_" + Date.now()
      });
    });
  }
  const fr = getActiveCliFrameEl();
  if (fr) {
    fr.setAttribute("tabindex", "0");
  }
  const stack = getCliFrameStackEl();
  if (stack) {
    stack.addEventListener("pointerdown", () => {
      setCliTerminalFocusLock(true);
      focusCliTerminalFrame();
    });
  }
  document.addEventListener("pointerdown", (e) => {
    if (getUIMode() !== "cli") return;
    const t = e.target;
    if (t && t.closest && (t.closest(".cli-frame-stack") || t.closest("#cli-engine-tabs") || t.closest("#cli-engine-sidebar") || t.closest("#compose-context-cli") || t.closest(".cli-bar") || t.closest("#cliQuickCmds") || t.closest(".wb-compose"))) {
      setCliTerminalFocusLock(true);
      if (t.closest(".cli-frame-stack")) {
        focusCliTerminalFrame();
      }
      return;
    }
    setCliTerminalFocusLock(false);
  }, true);
  renderCliQuickCmds();
}

function handleTtydHostMessage(payload) {
  if (!payload || !payload.type) return false;
  if (payload.type === "ttyd_ready") {
    const eng = normalizeCliEngineId(payload.engine || getActiveCliEngine());
    if (eng) {
      markCliEngineReady(eng);
      ensureCliFrameForEngine(eng);
    }
    resetCliOpenThrottle(eng);
    _cliAutoRetryCountByEngine.delete(eng);
    _cliLoadingPollCountByEngine.delete(eng);
    let turl = String(payload.baseUrl || "").trim();
    if (!turl) turl = cliUrlWithTheme(cliBaseUrlForEngine(eng));
    else turl = cliUrlWithTheme(turl);
    if (turl && eng) _cliUrlByEngine.set(eng, turl);
    const active = normalizeCliEngineId(getActiveCliEngine());
    if (turl && active === eng) {
      setActiveCliFrame(eng);
      applyCliFrameUrl(turl, eng);
      setCliLoadingVisible(false);
      stopCliLoadingPoll();
      renderCliEngineTabs();
    }
    const bootCmd = String(payload.autoBootCmd || "").trim();
    if (bootCmd) scheduleCliAutoBoot(eng, bootCmd);
    if (active !== eng) return true;
    const st = document.getElementById("status");
    if (st) st.textContent = "ttyd 终端已就绪";
    return true;
  }
  if (payload.type === "ttyd_error") {
    const eng = normalizeCliEngineId(payload.engine || "");
    if (eng && eng !== getActiveCliEngine()) return true;
    if (eng) clearCliEngineReady(eng);
    resetCliOpenThrottle(eng);
    _cliAutoRetryCountByEngine.delete(eng);
    _cliLoadingPollCountByEngine.delete(eng);
    if (eng === getActiveCliEngine()) setCliLoadingVisible(true, "ttyd 连接失败，可点「打开」重试");
    const st = document.getElementById("status");
    const msg = String(payload.message || "启动失败");
    if (st) {
      st.textContent = msg.indexOf("timeout") >= 0
        ? "ttyd 连接超时，可点「打开」或「重启」重试"
        : "ttyd：" + msg;
    }
    return true;
  }
  if (payload.type === "ttyd_status") {
    return true;
  }
  return false;
}


let _scCliControlsInited = false;
function ensureCliControlsInited() {
  if (_scCliControlsInited) return;
  _scCliControlsInited = true;
  initCliTerminalControls();
}

if (typeof globalThis !== "undefined") {
  globalThis.ScCli = globalThis.ScCli || { loaded: true };
  globalThis.ScCli.loaded = true;
  globalThis.ScCli.ensureControlsInited = ensureCliControlsInited;
  globalThis.renderCliEngineTabs = renderCliEngineTabs;
  globalThis.scheduleSyncCliWorkspace = scheduleSyncCliWorkspace;
  globalThis.syncCliWorkspace = syncCliWorkspace;
  globalThis.handleTtydHostMessage = handleTtydHostMessage;
  globalThis.ensureCliControlsInited = ensureCliControlsInited;
  globalThis.sendComposeToCli = sendComposeToCli;
  globalThis.setActiveCliFrame = setActiveCliFrame;
  globalThis.normalizeCliEngineId = normalizeCliEngineId;
  globalThis.setCliTerminalFocusLock = setCliTerminalFocusLock;
  globalThis.focusCliTerminalFrame = focusCliTerminalFrame;
}
