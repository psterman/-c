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
const SC_CLI_ENGINE_META = {
  codex_cli: { vendor: "OpenAI", capabilities: ["CLI", "代码"] },
  gemini_cli: { vendor: "Google", capabilities: ["CLI"] },
  openclaw_cli: { vendor: "OpenClaw", capabilities: ["CLI", "Agent"] },
  qwen_cli: { vendor: "阿里云", capabilities: ["CLI", "通义"] },
  ollama_cli: { vendor: "Ollama", capabilities: ["CLI", "本地"] },
  claude_cli: { vendor: "Anthropic", capabilities: ["CLI", "代码"] },
  deepseek_cli: { vendor: "DeepSeek", capabilities: ["CLI", "代码"] },
  kimi_cli: { vendor: "Moonshot", capabilities: ["CLI"] },
  zhipu_cli: { vendor: "智谱", capabilities: ["CLI"] },
  copilot_cli: { vendor: "GitHub", capabilities: ["CLI", "Copilot"] }
};
const SC_CLI_PENDING_FIELDS = [
  { key: "terminalOutput", label: "终端输出旁路", note: "需改 ttyd 承载方式" },
  { key: "modelMetrics", label: "模型内部指标", note: "需 CLI 侧 API" }
];
const SC_CLI_AUDIT_DEDUP_MS = 10000;
const SC_CLI_AUDIT_MAX = 20;
const SC_CLI_CMD_SUMMARY_MAX = 48;
const SC_CLI_DETAIL_RAIL_KEY = "sc_cli_detail_rail_v1";
const SC_CLI_TASK_TITLE_KEY = "sc_cli_task_title_v1";
const SC_CLI_DETAIL_NARROW_MQ = "(max-width: 900px)";
function cliEncodeStoragePart(s) {
  return encodeURIComponent(String(s || ""));
}
function cliTaskTitleStorageKey(engine) {
  const eng = normalizeCliEngineId(engine);
  const wd = String((ensureCliRuntime(eng).hostMeta || {}).workDir || "");
  return SC_CLI_TASK_TITLE_KEY + ":" + eng + ":" + cliEncodeStoragePart(wd);
}
function getCliTaskTitle(engine) {
  const eng = normalizeCliEngineId(engine || getActiveCliEngine());
  try {
    const v = localStorage.getItem(cliTaskTitleStorageKey(eng));
    if (v != null) return String(v);
  } catch (_) {}
  return ensureCliRuntime(eng).taskTitle || "";
}
function setCliTaskTitle(engine, title) {
  const eng = normalizeCliEngineId(engine || getActiveCliEngine());
  const rt = ensureCliRuntime(eng);
  const t = String(title || "");
  rt.taskTitle = t;
  try { localStorage.setItem(cliTaskTitleStorageKey(eng), t); } catch (_) {}
}
function syncCliTaskTitleInput(engine) {
  if (!isCliWorkbenchSurface()) return;
  const input = document.getElementById("cli-task-title");
  if (!input) return;
  const t = getCliTaskTitle(engine);
  if (document.activeElement !== input) input.value = t;
}
function applyCliDetailRailVisible() {
  if (!isCliWorkbenchSurface()) return;
  const layout = document.getElementById("layout");
  const toggle = document.getElementById("cli-detail-toggle");
  const userOpen = state.detailRailUserOpen !== false;
  const narrow = !!state.detailRailNarrowForced;
  const expanded = userOpen && !narrow;
  document.body.classList.toggle("cli-detail-collapsed", !expanded);
  if (layout) layout.classList.toggle("cli-detail-collapsed", !expanded);
  if (toggle) {
    toggle.setAttribute("aria-expanded", expanded ? "true" : "false");
    toggle.textContent = expanded ? "收起" : "详情";
  }
}
function setCliDetailRailUserOpen(open) {
  if (!isCliWorkbenchSurface()) return;
  state.detailRailUserOpen = !!open;
  try { localStorage.setItem(SC_CLI_DETAIL_RAIL_KEY, state.detailRailUserOpen ? "1" : "0"); } catch (_) {}
  applyCliDetailRailVisible();
}
function toggleCliDetailRail() {
  if (!isCliWorkbenchSurface()) return;
  setCliDetailRailUserOpen(!state.detailRailUserOpen);
}
function syncCliDetailRailResponsive() {
  if (!isCliWorkbenchSurface()) return;
  try {
    state.detailRailNarrowForced = window.matchMedia(SC_CLI_DETAIL_NARROW_MQ).matches;
  } catch (_) {
    state.detailRailNarrowForced = false;
  }
  applyCliDetailRailVisible();
}
function refreshCliWorkbenchUi(engine, engRow) {
  if (!isCliWorkbenchSurface()) return;
  const eng = normalizeCliEngineId(engine || getActiveCliEngine());
  const row = engRow || getCliEnginesForTabs().find((e) => e && e.value === eng);
  updateCliTopbar(eng, row);
  renderCliModelDetail(eng);
  renderCliSidebarContext(eng);
  syncCliTaskTitleInput(eng);
}
function renderCliSidebarContext(engine) {
  if (!isCliWorkbenchSurface()) return;
  const body = document.getElementById("cli-sidebar-context-body");
  if (!body) return;
  const eng = normalizeCliEngineId(engine || getActiveCliEngine());
  const hm = (ensureCliRuntime(eng).hostMeta || {});
  const workDir = hm.workDir ? String(hm.workDir) : "";
  let html = "";
  html += "<div class=\"cli-sidebar-ctx-row\"><span class=\"cli-sidebar-ctx-label\">目录</span><span class=\"cli-sidebar-ctx-val\" title=\"" + escapeAttr(workDir) + "\">" + escapeHtml(workDir ? cliTruncatePath(workDir, 42) : "未检测到") + "</span></div>";
  html += "<div class=\"cli-sidebar-ctx-row\"><span class=\"cli-sidebar-ctx-label\">分支</span><span class=\"cli-sidebar-ctx-val\">" + escapeHtml(cliFormatGitBranch(hm)) + "</span></div>";
  const entries = Array.isArray(hm.dirEntries) ? hm.dirEntries : [];
  if (entries.length) {
    html += "<ul class=\"cli-dir-list\">";
    entries.slice(0, 12).forEach((item) => {
      if (!item) return;
      const name = String(item.name || "");
      const isDir = !!item.isDir;
      html += "<li class=\"cli-dir-entry" + (isDir ? " cli-dir-entry--folder" : "") + "\">" + escapeHtml((isDir ? "📁 " : "📄 ") + name) + "</li>";
    });
    html += "</ul>";
  }
  body.innerHTML = html;
}
function cliEngineMeta(engineId) {
  const id = normalizeCliEngineId(engineId);
  const base = SC_CLI_ENGINE_META[id] || { vendor: "—", capabilities: ["CLI"] };
  const tool = String(SC_CLI_AUTO_BOOT_CMD[id] || "").trim();
  return Object.assign({ tool: tool || "—" }, base);
}
function isCliWorkbenchSurface() {
  return !!document.body && document.body.classList.contains("wb-cli-layout")
    && !!document.querySelector("#layout.wb-app.sc-cli-active");
}
function ensureCliRuntime(engine) {
  const eng = normalizeCliEngineId(engine || getActiveCliEngine());
  if (!state.cliRuntime || typeof state.cliRuntime !== "object") state.cliRuntime = {};
  if (!state.cliRuntime[eng]) {
    state.cliRuntime[eng] = {
      lastInput: "",
      recentCommands: [],
      busy: false,
      errorCount: 0,
      lastError: "",
      openRequestedAt: 0,
      connectMs: null,
      retryCount: 0,
      lastRetryAt: 0,
      lastReadyAt: 0,
      lastErrorAt: 0,
      auditLog: [],
      taskTitle: "",
      hostMeta: null,
      pendingReqId: ""
    };
  }
  return state.cliRuntime[eng];
}
function cliShouldRefreshRuntimeUi(engine, reqId, partial) {
  const eng = normalizeCliEngineId(engine);
  if (normalizeCliEngineId(getActiveCliEngine()) !== eng) return false;
  if (partial) return true;
  if (reqId === "init") return true;
  const rt = ensureCliRuntime(eng);
  if (!reqId) return true;
  return String(reqId) === String(rt.pendingReqId || "");
}
function cliApplyHostMeta(engine, meta, opts) {
  const eng = normalizeCliEngineId(engine);
  if (!meta || typeof meta !== "object") return false;
  const rt = ensureCliRuntime(eng);
  const prev = rt.hostMeta && typeof rt.hostMeta === "object" ? rt.hostMeta : {};
  const options = opts || {};
  const partial = String(options.partial || "");
  if (partial === "stats") {
    rt.hostMeta = Object.assign({}, prev, {
      cpuPercent: meta.cpuPercent !== undefined ? meta.cpuPercent : prev.cpuPercent,
      memoryMb: meta.memoryMb !== undefined ? meta.memoryMb : prev.memoryMb,
      statsAt: meta.statsAt != null ? meta.statsAt : prev.statsAt
    });
  } else {
    const next = Object.assign({}, prev, meta);
    if (Array.isArray(meta.dirEntries)) next.dirEntries = meta.dirEntries;
    else if (!meta.dirEntries && Array.isArray(prev.dirEntries)) next.dirEntries = prev.dirEntries;
    rt.hostMeta = next;
    if (meta.fetchError) rt.hostMeta.fetchError = String(meta.fetchError);
    else if (rt.hostMeta.fetchError && meta.workDir) delete rt.hostMeta.fetchError;
  }
  if (options.refreshUi && cliShouldRefreshRuntimeUi(eng, options.reqId, !!partial)) {
    if (partial === "stats") renderCliModelDetail(eng);
    else refreshCliWorkbenchUi(eng);
  }
  return true;
}
function requestCliEngineRuntime(engine, reason) {
  if (!isCliWorkbenchSurface()) return;
  const eng = normalizeCliEngineId(engine || getActiveCliEngine());
  const rt = ensureCliRuntime(eng);
  const reqId = "cer_" + Date.now();
  rt.pendingReqId = reqId;
  rt.runtimeRequestedAt = Date.now();
  postToAhk({ type: "cli_engine_changed", engine: eng, reqId: reqId, reason: String(reason || "") });
}
function handleCliEngineRuntimeMessage(payload) {
  if (!payload || payload.type !== "cli_engine_runtime") return false;
  if (!isCliWorkbenchSurface()) return false;
  const eng = normalizeCliEngineId(payload.engine || "");
  if (!eng) return true;
  const reqId = String(payload.reqId || "");
  const partial = String(payload.partial || "");
  const rt = ensureCliRuntime(eng);
  if (payload.ok === false) {
    rt.hostMeta = Object.assign({}, rt.hostMeta || {}, {
      fetchError: String(payload.error || "获取失败")
    });
  } else if (payload.engineRuntime) {
    cliApplyHostMeta(eng, payload.engineRuntime, { reqId, refreshUi: false, partial });
  }
  if (cliShouldRefreshRuntimeUi(eng, reqId, !!partial)) {
    if (partial === "stats") renderCliModelDetail(eng);
    else refreshCliWorkbenchUi(eng);
  }
  return true;
}
function handleCliAuditMessage(payload) {
  if (!payload || payload.type !== "cli_audit_event") return false;
  if (!isCliWorkbenchSurface()) return false;
  const eng = normalizeCliEngineId(payload.engine || getActiveCliEngine());
  cliPushAudit(eng, payload.kind || "system", payload.level || "info", payload.message || "");
  if (eng === normalizeCliEngineId(getActiveCliEngine())) renderCliModelDetail(eng);
  return true;
}
function cliConnStateForEngine(engine) {
  const eng = normalizeCliEngineId(engine);
  const rt = ensureCliRuntime(eng);
  if (rt.lastError && !isCliEngineReady(eng)) return "error";
  if (isCliEngineReady(eng)) return "ready";
  if (rt.openRequestedAt > 0 || rt.busy) return "loading";
  return "idle";
}
function cliConnStateLabel(stateKey) {
  if (stateKey === "ready") return "已连接";
  if (stateKey === "loading") return "连接中";
  if (stateKey === "error") return "连接失败";
  return "未连接";
}
function cliTruncatePath(p, max) {
  const s = String(p || "").trim();
  if (!s) return "";
  max = max || 36;
  if (s.length <= max) return s;
  return "…" + s.slice(-(max - 1));
}
function cliSummarizeCommand(text, max) {
  const s = String(text || "").trim();
  max = max || SC_CLI_CMD_SUMMARY_MAX;
  if (!s) return "";
  if (s.length <= max) return s;
  return s.slice(0, max - 1) + "…";
}
function cliNormalizeCommandEntry(c) {
  if (c && typeof c === "object" && c.text) {
    return { text: String(c.text), summary: String(c.summary || cliSummarizeCommand(c.text)) };
  }
  const t = String(c || "").trim();
  return t ? { text: t, summary: cliSummarizeCommand(t) } : null;
}
function cliFormatRelativeTime(ts) {
  if (ts == null || ts === "") return "";
  let ms = Number(ts);
  if (!isFinite(ms) || ms <= 0) return "";
  if (ms < 1e12) ms *= 1000;
  const diff = Date.now() - ms;
  if (diff < 45000) return "刚刚";
  if (diff < 3600000) return Math.floor(diff / 60000) + " 分钟前";
  if (diff < 86400000) return Math.floor(diff / 3600000) + " 小时前";
  if (diff < 604800000) return Math.floor(diff / 86400000) + " 天前";
  const d = new Date(ms);
  const hh = String(d.getHours()).padStart(2, "0");
  const mm = String(d.getMinutes()).padStart(2, "0");
  return (d.getMonth() + 1) + "-" + d.getDate() + " " + hh + ":" + mm;
}
function cliFormatGitStatus(hm) {
  hm = hm && typeof hm === "object" ? hm : {};
  if (hm.gitRepo === false) return "非 Git 目录";
  const st = hm.gitStatus ? String(hm.gitStatus) : "";
  const mc = Number(hm.modifiedCount) || 0;
  const uc = Number(hm.untrackedCount) || 0;
  if (!st) return "未检测到";
  if (st === "clean") return "clean";
  if (st === "modified") return "modified (" + mc + ")";
  if (st === "untracked") return "untracked (" + uc + ")";
  if (st === "mixed") return "mixed (" + mc + "+" + uc + ")";
  return st;
}
function cliFormatGitBranch(hm) {
  hm = hm && typeof hm === "object" ? hm : {};
  if (hm.gitRepo === false) return "非 Git 目录";
  const branch = hm.branch ? String(hm.branch) : "";
  if (branch) return branch;
  return "未检测到";
}
function cliFormatCommit(hm) {
  if (!hm || typeof hm !== "object") return "未检测到";
  if (hm.gitRepo === false) return "非 Git 目录";
  const hash = hm.commitHash ? String(hm.commitHash) : "";
  const subj = hm.commitSubject ? String(hm.commitSubject) : "";
  const at = hm.commitAt ? String(hm.commitAt) : "";
  const legacy = hm.recentCommit ? String(hm.recentCommit) : "";
  if (!hash && legacy) return legacy;
  if (!hash) return "未检测到";
  const rel = cliFormatRelativeTime(at);
  const title = cliTruncatePath(subj || "—", 36);
  return hash + " " + title + (rel ? " · " + rel : "");
}
function cliFormatResourceStats(hm) {
  hm = hm && typeof hm === "object" ? hm : {};
  const cpuRaw = hm.cpuPercent;
  const memRaw = hm.memoryMb;
  let cpuLabel = "采样中";
  if (cpuRaw === null || cpuRaw === "") cpuLabel = "—";
  else if (cpuRaw !== undefined) cpuLabel = String(cpuRaw) + "%";
  let memLabel = "采样中";
  if (memRaw === null || memRaw === "") memLabel = "—";
  else {
    const memMb = Number(memRaw);
    if (!isNaN(memMb)) memLabel = memMb >= 1024 ? (memMb / 1024).toFixed(1) + " GB" : memMb.toFixed(0) + " MB";
  }
  return "CPU " + cpuLabel + " | 内存 " + memLabel;
}
function cliPushAudit(engine, kind, level, message) {
  if (!isCliWorkbenchSurface()) return;
  const eng = normalizeCliEngineId(engine || getActiveCliEngine());
  const rt = ensureCliRuntime(eng);
  const k = String(kind || "system");
  const lv = String(level || "info");
  const msg = String(message || "").trim();
  if (!msg) return;
  const now = Date.now();
  if (!Array.isArray(rt.auditLog)) rt.auditLog = [];
  const last = rt.auditLog.length ? rt.auditLog[rt.auditLog.length - 1] : null;
  if (last && last.kind === k && (now - Number(last.ts || 0)) < SC_CLI_AUDIT_DEDUP_MS) {
    last.ts = now;
    last.message = msg;
    last.count = (Number(last.count) || 1) + 1;
    return;
  }
  rt.auditLog.push({ ts: now, kind: k, level: lv, message: msg, count: 1 });
  if (rt.auditLog.length > SC_CLI_AUDIT_MAX) rt.auditLog = rt.auditLog.slice(-SC_CLI_AUDIT_MAX);
}
function cliTrackCommandSent(engine, text) {
  const eng = normalizeCliEngineId(engine);
  const rt = ensureCliRuntime(eng);
  const cmd = String(text || "").trim();
  if (!cmd) return;
  rt.lastInput = cmd;
  rt.busy = true;
  const entry = { text: cmd, summary: cliSummarizeCommand(cmd) };
  const prev = (rt.recentCommands || []).map(cliNormalizeCommandEntry).filter(Boolean);
  rt.recentCommands = [entry].concat(prev.filter((c) => c.text !== cmd)).slice(0, 5);
}
function cliDetailValClass(kind) {
  if (kind === "error") return "cli-val-error";
  if (kind === "pending") return "cli-val-pending";
  if (kind === "unknown") return "cli-val-unknown";
  return "cli-val-ok";
}
function cliRenderDetailDl(rows) {
  let html = '<dl class="cli-detail-dl">';
  rows.forEach((row) => {
    if (!row) return;
    const cls = cliDetailValClass(row.kind);
    const val = row.html != null ? row.html : escapeHtml(row.value);
    html += "<dt>" + escapeHtml(row.label) + "</dt><dd class=\"" + cls + "\">" + val + "</dd>";
  });
  html += "</dl>";
  return html;
}
function cliRenderCommandHistory(rt) {
  const items = (rt.recentCommands || []).map(cliNormalizeCommandEntry).filter(Boolean).slice(0, 5);
  if (!items.length) return "—";
  let html = '<ul class="cli-cmd-history">';
  items.forEach((item) => {
    html += '<li title="' + escapeAttr(item.text) + '">' + escapeHtml(item.summary) + "</li>";
  });
  html += "</ul>";
  return html;
}
function cliRenderAuditTimeline(rt) {
  const rows = (rt.auditLog || []).slice(-5).reverse();
  if (!rows.length) return '<span class="cli-val-unknown">暂无事件</span>';
  let html = '<ul class="cli-audit-list">';
  rows.forEach((row) => {
    const kind = escapeHtml(row.kind || "system");
    const time = escapeHtml(cliFormatRelativeTime(row.ts) || "—");
    const msg = escapeHtml(row.message || "");
    const cnt = Number(row.count) > 1 ? " ×" + row.count : "";
    html += '<li class="cli-audit-item cli-audit-' + kind + '"><span class="cli-audit-time">' + time + '</span><span class="cli-audit-msg">' + msg + cnt + "</span></li>";
  });
  html += "</ul>";
  return html;
}
function cliRenderTtydUrlRow(eng) {
  const full = getCliTtydUrlForCopy(eng) || cliBaseUrlForEngine(eng);
  let summary = "未就绪";
  try {
    const u = new URL(full, window.location.href);
    summary = u.hostname + ":" + (u.port || cliPortForEngine(eng));
  } catch (_) {
    summary = cliTruncatePath(full, 28);
  }
  return '<div class="cli-url-row">' +
    '<span class="cli-url-summary">' + escapeHtml(summary) + "</span>" +
    '<button type="button" class="cli-url-copy cli-compose-act" data-act="copyurl" title="复制 URL">复制</button>' +
    '<details class="cli-url-details"><summary>详情</summary><code class="cli-url-full">' + escapeHtml(full) + "</code></details>" +
    "</div>";
}
function renderCliModelDetail(engine) {
  if (!isCliWorkbenchSurface()) return;
  const body = document.getElementById("cli-detail-body");
  if (!body) return;
  const eng = normalizeCliEngineId(engine || getActiveCliEngine());
  const rt = ensureCliRuntime(eng);
  const conn = cliConnStateForEngine(eng);
  const port = cliPortForEngine(eng);
  const connectMs = rt.connectMs != null ? String(rt.connectMs) + " ms" : "—";
  const lastErr = rt.lastError ? String(rt.lastError) : "—";
  const hm = rt.hostMeta && typeof rt.hostMeta === "object" ? rt.hostMeta : {};
  const workDir = hm.workDir ? String(hm.workDir) : "";
  const hostPort = hm.port != null ? String(hm.port) : String(port);
  const shell = hm.shell ? cliTruncatePath(String(hm.shell), 56) : "";
  const nodeVer = hm.nodeVersion ? String(hm.nodeVersion) : "";
  const pyVer = hm.pythonVersion ? String(hm.pythonVersion) : "";
  const gitVer = hm.gitVersion ? String(hm.gitVersion).replace(/^git version\s+/i, "") : "";
  const cliToolVer = hm.cliToolVersion ? String(hm.cliToolVersion) : "";
  const envParts = [];
  if (nodeVer) envParts.push("Node " + nodeVer);
  else if (pyVer) envParts.push("Python " + pyVer);
  if (gitVer) envParts.push("Git " + gitVer);
  if (cliToolVer) envParts.push(cliToolVer);
  const envText = envParts.length ? envParts.join(" | ") : "未检测到";
  const taskTitle = getCliTaskTitle(eng) || "—";
  const readyRel = rt.lastReadyAt ? cliFormatRelativeTime(rt.lastReadyAt) : "—";
  const errRel = rt.lastErrorAt ? cliFormatRelativeTime(rt.lastErrorAt) : "—";
  const retryRel = rt.lastRetryAt ? cliFormatRelativeTime(rt.lastRetryAt) : "—";
  let html = "";
  html += "<section class=\"cli-detail-group cli-detail-section\"><div class=\"cli-detail-section-title\">任务上下文</div>";
  html += cliRenderDetailDl([
    { label: "任务便签", value: taskTitle, kind: taskTitle !== "—" ? "ok" : "unknown" },
    { label: "工作目录", value: workDir ? cliTruncatePath(workDir, 48) : (hm.fetchError ? String(hm.fetchError) : "未检测到"), kind: workDir ? "ok" : "unknown" },
    { label: "Git 分支", value: cliFormatGitBranch(hm), kind: hm.branch ? "ok" : (hm.gitRepo === false ? "unknown" : "unknown") },
    { label: "Git 状态", value: cliFormatGitStatus(hm), kind: hm.gitStatus ? "ok" : "unknown" },
    { label: "最近 commit", value: cliFormatCommit(hm), kind: (hm.commitHash || hm.recentCommit) ? "ok" : "unknown" },
    { label: "最近命令", html: cliRenderCommandHistory(rt), kind: (rt.recentCommands || []).length ? "ok" : "unknown" }
  ]);
  html += "</section>";
  html += "<section class=\"cli-detail-group cli-detail-section\"><div class=\"cli-detail-section-title\">连接与观测</div>";
  html += cliRenderDetailDl([
    { label: "连接", value: cliConnStateLabel(conn), kind: conn === "error" ? "error" : (conn === "ready" ? "ok" : "unknown") },
    { label: "端口", value: hostPort, kind: "ok" },
    { label: "连接耗时", value: connectMs, kind: rt.connectMs != null ? "ok" : "unknown" },
    { label: "就绪时间", value: readyRel, kind: rt.lastReadyAt ? "ok" : "unknown" },
    { label: "最近错误", value: errRel + (rt.lastError ? " · " + cliTruncatePath(lastErr, 32) : ""), kind: rt.lastErrorAt ? "error" : "ok" },
    { label: "重试", value: (rt.retryCount || 0) + " 次" + (retryRel !== "—" ? " · " + retryRel : ""), kind: rt.retryCount ? "unknown" : "ok" },
    { label: "错误次数", value: String(rt.errorCount || 0), kind: rt.errorCount ? "error" : "ok" },
    { label: "资源占用", value: cliFormatResourceStats(hm), kind: "ok" },
    { label: "环境", value: envText, kind: envParts.length ? "ok" : "unknown" },
    { label: "Shell", value: shell || "未检测到", kind: shell ? "ok" : "unknown" },
    { label: "ttyd", html: cliRenderTtydUrlRow(eng), kind: "ok" },
    { label: "事件", html: cliRenderAuditTimeline(rt), kind: (rt.auditLog || []).length ? "ok" : "unknown" }
  ]);
  html += "</section>";
  html += "<details class=\"cli-detail-pending\"><summary>待接入</summary>";
  html += cliRenderDetailDl(SC_CLI_PENDING_FIELDS.map((f) => ({
    label: f.label,
    value: f.note || "未接入",
    kind: "pending"
  })));
  html += "</details>";
  body.innerHTML = html;
}
function updateCliTopbar(engine, engRow) {
  if (!isCliWorkbenchSurface()) return;
  const eng = normalizeCliEngineId(engine || getActiveCliEngine());
  const row = engRow || getCliEnginesForTabs().find((e) => e && e.value === eng);
  const name = (row && row.name) ? row.name : eng;
  const port = cliPortForEngine(eng);
  const conn = cliConnStateForEngine(eng);
  const rt = ensureCliRuntime(eng);
  const titleEl = document.getElementById("cli-topbar-title");
  const dotEl = document.getElementById("cli-conn-dot");
  const connTextEl = document.getElementById("cli-topbar-conn");
  const latencyEl = document.getElementById("cli-topbar-latency");
  const topStatus = document.getElementById("wb-topbar-status");
  const shellTitle = document.getElementById("cliTitle");
  if (titleEl) titleEl.textContent = name;
  if (dotEl) {
    dotEl.dataset.state = conn;
    dotEl.title = cliConnStateLabel(conn);
  }
  if (connTextEl) {
    connTextEl.textContent = cliConnStateLabel(conn);
    connTextEl.dataset.state = conn;
  }
  if (latencyEl) {
    latencyEl.textContent = rt.connectMs != null ? "耗时 " + rt.connectMs + " ms" : "";
  }
  if (topStatus) topStatus.textContent = ":" + port;
  if (shellTitle) shellTitle.textContent = name + " · ttyd :" + port;
}
function cliDispatchTerminalAction(fn) {
  if (!isCliWorkbenchSurface()) {
    if (typeof fn === "function") fn();
    return;
  }
  scheduleCliTerminalFocusForSend();
  setTimeout(() => { if (typeof fn === "function") fn(); }, 90);
}
let _cliWbSurfaceInited = false;
function runCliComposeAction(act) {
  const a = String(act || "");
  if (a === "send") {
    sendComposeToCli();
    return;
  }
  if (a === "interrupt") cliDispatchTerminalAction(() => interruptCli());
  else if (a === "paste") cliDispatchTerminalAction(() => pasteToCli());
  else if (a === "clear") cliDispatchTerminalAction(() => clearCliTerminal());
  else if (a === "retry") retryCliConnection();
  else if (a === "copyurl") copyCliTtydUrl();
  else if (a === "workdir") openCliWorkDir();
  else if (a === "external") openCliExternal();
  else if (a === "quick") toggleCliQuickPanel();
}
function initCliWorkbenchSurface() {
  if (!isCliWorkbenchSurface() || _cliWbSurfaceInited) return;
  _cliWbSurfaceInited = true;
  try {
    const v = localStorage.getItem(SC_CLI_DETAIL_RAIL_KEY);
    state.detailRailUserOpen = (v !== "0");
  } catch (_) {
    state.detailRailUserOpen = true;
  }
  syncCliDetailRailResponsive();
  const toggle = document.getElementById("cli-detail-toggle");
  if (toggle) toggle.addEventListener("click", () => toggleCliDetailRail());
  const taskInput = document.getElementById("cli-task-title");
  if (taskInput) {
    taskInput.addEventListener("change", () => {
      setCliTaskTitle(getActiveCliEngine(), taskInput.value);
      renderCliModelDetail(getActiveCliEngine());
    });
    taskInput.addEventListener("blur", () => {
      setCliTaskTitle(getActiveCliEngine(), taskInput.value);
      renderCliModelDetail(getActiveCliEngine());
    });
  }
  const dock = document.querySelector(".cli-compose-dock");
  if (dock) {
    dock.addEventListener("click", (e) => {
      const sum = e.target.closest(".cli-compose-more > summary");
      if (sum) return;
      const btn = e.target.closest(".cli-compose-act[data-act]");
      if (!btn) return;
      e.preventDefault();
      runCliComposeAction(btn.dataset.act);
    });
  }
  const detailBody = document.getElementById("cli-detail-body");
  if (detailBody) {
    detailBody.addEventListener("click", (e) => {
      const btn = e.target.closest("[data-act]");
      if (!btn || !btn.dataset.act) return;
      e.preventDefault();
      runCliComposeAction(btn.dataset.act);
    });
  }
  try {
    window.matchMedia(SC_CLI_DETAIL_NARROW_MQ).addEventListener("change", syncCliDetailRailResponsive);
  } catch (_) {}
}
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
function getCliTerminalClickPoint() {
  const stack = getCliFrameStackEl();
  const fr = getActiveCliFrameEl();
  const el = fr || stack;
  if (!el || !el.getBoundingClientRect) return null;
  const rect = el.getBoundingClientRect();
  if (rect.width < 8 || rect.height < 8) return null;
  return {
    x: Math.round(rect.left + rect.width * 0.5),
    y: Math.round(rect.top + Math.min(rect.height * 0.72, rect.height - 16))
  };
}
function cliSendHostExtras() {
  if (!isCliWorkbenchSurface()) return {};
  const pt = getCliTerminalClickPoint();
  if (!pt) return {};
  return { clickX: pt.x, clickY: pt.y };
}
function scheduleCliTerminalFocusForSend() {
  setCliTerminalFocusLock(true);
  const input = document.getElementById("search");
  if (input && document.activeElement === input) {
    try { input.blur(); } catch (_) {}
  }
  focusCliTerminalFrame();
  requestAnimationFrame(() => {
    focusCliTerminalFrame();
    requestAnimationFrame(() => focusCliTerminalFrame());
  });
}
let _cliPendingComposeSend = "";
function sendComposeToCli() {
  const input = document.getElementById("search");
  const keyword = input ? String(input.value || "").trim() : "";
  if (!keyword) {
    const st = document.getElementById("status");
    if (st) st.textContent = "请输入要发送的内容";
    return;
  }
  state.keyword = keyword;
  const eng = getActiveCliEngine();
  const ready = isCliEngineReady(eng) && cliFrameUrlLooksLiveForPort(cliPortForEngine(eng));
  if (isCliWorkbenchSurface()) {
    ensureCliFrameForEngine(eng);
    setActiveCliFrame(eng);
    scheduleCliTerminalFocusForSend();
  }
  if (!ready) {
    _cliPendingComposeSend = keyword;
    setCliLoadingVisible(true, "终端初始化中，请稍候…");
    throttledNiumaCliOpen(false);
  } else {
    _cliPendingComposeSend = "";
  }
  const payload = Object.assign({ type: "cliSend", prompt: keyword, engine: eng }, cliSendHostExtras());
  const fireSend = () => {
    postToAhk(payload);
    cliTrackCommandSent(eng, keyword);
    cliPushAudit(eng, "send", "info", "已发送: " + cliSummarizeCommand(keyword, 40));
    if (isCliWorkbenchSurface()) renderCliModelDetail(eng);
    if (input) {
      input.value = "";
      input.style.height = "auto";
      state.keyword = "";
    }
    const st = document.getElementById("status");
    if (st && ready) st.textContent = "已发送到终端";
  };
  if (isCliWorkbenchSurface()) {
    setTimeout(fireSend, 90);
  } else {
    fireSend();
  }
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
  ensureCliRuntime(engine).openRequestedAt = now;
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
  refreshCliWorkbenchUi(engine, engRow);
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
      const statusText = ready
        ? (isActive ? "就绪" : "待命")
        : (isActive ? "连接中" : "未连接");
      btn.innerHTML =
        "<span class=\"sc-web-ai-row__icon\">" + iconHtml + "</span>" +
        "<span class=\"sc-web-ai-row__main\">" +
          "<span class=\"sc-web-ai-row__title\">" + escapeHtml((engine.name || engId) + " · " + cliEngineRoleLabel(engId)) + "</span>" +
          "<span class=\"sc-web-ai-row__sub\">" + escapeHtml(statusText) + "</span>" +
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
      requestCliEngineRuntime(id, "switch");
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
  if (isCliWorkbenchSurface()) {
    ensureCliFrameForEngine(eng);
    setActiveCliFrame(eng);
    scheduleCliTerminalFocusForSend();
  } else {
    setCliTerminalFocusLock(true);
  }
  postToAhk(Object.assign({ type: "cliSend", prompt: text, engine: eng }, cliSendHostExtras()));
  cliTrackCommandSent(eng, text);
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
  const wbDock = isCliWorkbenchSurface() && wrap.classList.contains("cli-quick-cmds-bottom");
  const open = wbDock || isCliQuickPanelOpen();
  wrap.classList.toggle("hidden", !open);
  if (toggleBtn) toggleBtn.classList.toggle("primary", open && !wbDock);
  if (!open) {
    wrap.innerHTML = "";
    return;
  }
  const engine = getActiveCliEngine();
  const cmds = getCliQuickCmdsForEngine(engine);
  wrap.innerHTML = "";
  if (wbDock) {
    const label = document.createElement("span");
    label.className = "cli-quick-cmds-label";
    label.textContent = "常用命令";
    wrap.appendChild(label);
  }
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

function openCliWorkDir() {
  const engine = getActiveCliEngine();
  postToAhk({ type: "niuma_cli_open_workdir", engine, reqId: "sc_wd_" + Date.now() });
}
function pasteToCli() {
  const engine = getActiveCliEngine();
  setCliTerminalFocusLock(true);
  postToAhk(Object.assign({ type: "cliPaste", engine }, cliSendHostExtras()));
}
function interruptCli() {
  const engine = getActiveCliEngine();
  setCliTerminalFocusLock(true);
  postToAhk(Object.assign({ type: "cliInterrupt", engine }, cliSendHostExtras()));
}
function openCliExternal() {
  const engine = getActiveCliEngine();
  postToAhk({
    type: "niuma_cli_open_external",
    engine,
    baseUrl: cliUrlWithTheme(cliBaseUrlForEngine(engine)),
    reqId: "sc_x_" + Date.now()
  });
}
function toggleCliQuickPanel() {
  setCliQuickPanelOpen(!isCliQuickPanelOpen());
}
function clearCliTerminal() {
  sendCliQuickCmd("cls");
}
function retryCliConnection() {
  const eng = getActiveCliEngine();
  if (isCliWorkbenchSurface()) {
    const rt = ensureCliRuntime(eng);
    rt.retryCount = (Number(rt.retryCount) || 0) + 1;
    rt.lastRetryAt = Date.now();
    cliPushAudit(eng, "retry", "warn", "发起重连");
    renderCliModelDetail(eng);
    clearCliEngineReady(eng);
    resetCliOpenThrottle(eng);
    postToAhk({
      type: "niuma_cli_restart",
      engine: eng,
      baseUrl: cliBaseUrlForEngine(eng),
      reqId: "sc_retry_" + Date.now()
    });
    setCliLoadingVisible(true, "正在重连…");
    return;
  }
  throttledNiumaCliOpen(true);
}
function getCliTtydUrlForCopy(engine) {
  const eng = normalizeCliEngineId(engine);
  const cached = String(_cliUrlByEngine.get(eng) || "").trim();
  if (cached && cached.indexOf("about:blank") !== 0) return cached;
  if (isCliEngineReady(eng)) return cliUrlWithTheme(cliBaseUrlForEngine(eng));
  return "";
}
function copyCliTtydUrl() {
  const eng = getActiveCliEngine();
  const url = getCliTtydUrlForCopy(eng);
  const st = document.getElementById("status");
  if (!url) {
    if (st) st.textContent = "暂无可用连接地址";
    return;
  }
  const done = () => { if (st) st.textContent = "已复制 ttyd URL"; };
  const fail = () => { if (st) st.textContent = "复制失败"; };
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(url).then(done).catch(fail);
  } else {
    try {
      const ta = document.createElement("textarea");
      ta.value = url;
      document.body.appendChild(ta);
      ta.select();
      document.execCommand("copy");
      document.body.removeChild(ta);
      done();
    } catch (_) {
      fail();
    }
  }
}

function initCliTerminalControls() {
  const workDirBtn = document.getElementById("cliWorkDirBtn");
  const pasteBtn = document.getElementById("cliPasteBtn");
  const interruptBtn = document.getElementById("cliInterruptBtn");
  const quickToggleBtn = document.getElementById("cliQuickToggleBtn");
  const popBtn = document.getElementById("cliPopBtn");
  if (workDirBtn) workDirBtn.addEventListener("click", () => openCliWorkDir());
  if (pasteBtn) pasteBtn.addEventListener("click", () => pasteToCli());
  if (interruptBtn) interruptBtn.addEventListener("click", () => interruptCli());
  if (quickToggleBtn) quickToggleBtn.addEventListener("click", () => toggleCliQuickPanel());
  if (popBtn) popBtn.addEventListener("click", () => openCliExternal());
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
    if (t && t.closest && (t.closest("#cli-detail-rail") || t.closest("#cli-sidebar-context") || t.closest("#cli-task-title"))) {
      setCliTerminalFocusLock(false);
      return;
    }
    if (t && t.closest && t.closest(".cli-frame-stack")) {
      setCliTerminalFocusLock(true);
      focusCliTerminalFrame();
      return;
    }
    if (t && t.closest && (t.closest(".wb-compose-inner") || t.closest("#search") || t.closest(".cli-compose-dock"))) {
      setCliTerminalFocusLock(false);
      return;
    }
    if (t && t.closest && (t.closest("#cli-engine-tabs") || t.closest("#cli-engine-sidebar") || t.closest("#compose-context-cli") || t.closest(".cli-bar"))) {
      setCliTerminalFocusLock(false);
      return;
    }
    if (t && t.closest && (t.closest("#cliQuickCmds") || t.closest(".cli-compose-toolbar") || t.closest(".cli-compose-more"))) {
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
    const rt = eng ? ensureCliRuntime(eng) : null;
    if (eng) {
      markCliEngineReady(eng);
      ensureCliFrameForEngine(eng);
    }
    if (rt) {
      rt.busy = false;
      rt.lastError = "";
      rt.lastReadyAt = Date.now();
      cliPushAudit(eng, "ready", "success", "终端已就绪");
      const started = Number(rt.openRequestedAt) || 0;
      if (started > 0) rt.connectMs = Math.max(0, Date.now() - started);
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
      if (active === eng) refreshCliWorkbenchUi(eng);
    }
    const bootCmd = String(payload.autoBootCmd || "").trim();
    if (bootCmd) scheduleCliAutoBoot(eng, bootCmd);
    if (active !== eng) return true;
    const st = document.getElementById("status");
    if (st) st.textContent = "ttyd 终端已就绪";
    refreshCliWorkbenchUi(eng);
    if (isCliWorkbenchSurface()) requestCliEngineRuntime(eng, "ttyd_ready");
    if (_cliPendingComposeSend && isCliWorkbenchSurface()) {
      const pending = String(_cliPendingComposeSend || "").trim();
      _cliPendingComposeSend = "";
      if (pending) {
        setTimeout(() => {
          scheduleCliTerminalFocusForSend();
          postToAhk(Object.assign({ type: "cliSend", prompt: pending, engine: eng }, cliSendHostExtras()));
          cliTrackCommandSent(eng, pending);
        }, 320);
      }
    }
    return true;
  }
  if (payload.type === "ttyd_error") {
    const eng = normalizeCliEngineId(payload.engine || "");
    const rt = eng ? ensureCliRuntime(eng) : null;
    if (eng && rt) {
      rt.busy = false;
      rt.errorCount = (Number(rt.errorCount) || 0) + 1;
      rt.lastError = String(payload.message || "启动失败");
      rt.lastErrorAt = Date.now();
      cliPushAudit(eng, "error", "error", String(payload.message || "启动失败").slice(0, 80));
    }
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
    if (eng === getActiveCliEngine()) {
      refreshCliWorkbenchUi(eng);
      renderCliEngineTabs();
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
  initCliWorkbenchSurface();
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
  globalThis.isCliWorkbenchSurface = isCliWorkbenchSurface;
  globalThis.initCliWorkbenchSurface = initCliWorkbenchSurface;
  globalThis.renderCliModelDetail = renderCliModelDetail;
  globalThis.updateCliTopbar = updateCliTopbar;
  globalThis.toggleCliDetailRail = toggleCliDetailRail;
  globalThis.syncCliDetailRailResponsive = syncCliDetailRailResponsive;
  globalThis.cliApplyHostMeta = cliApplyHostMeta;
  globalThis.requestCliEngineRuntime = requestCliEngineRuntime;
  globalThis.handleCliEngineRuntimeMessage = handleCliEngineRuntimeMessage;
  globalThis.handleCliAuditMessage = handleCliAuditMessage;
  globalThis.refreshCliWorkbenchUi = refreshCliWorkbenchUi;
  globalThis.renderCliSidebarContext = renderCliSidebarContext;
  globalThis.openCliWorkDir = openCliWorkDir;
  globalThis.pasteToCli = pasteToCli;
  globalThis.interruptCli = interruptCli;
  globalThis.openCliExternal = openCliExternal;
  globalThis.clearCliTerminal = clearCliTerminal;
  globalThis.retryCliConnection = retryCliConnection;
  globalThis.copyCliTtydUrl = copyCliTtydUrl;
  globalThis.getCliTaskTitle = getCliTaskTitle;
  globalThis.setCliTaskTitle = setCliTaskTitle;
}
