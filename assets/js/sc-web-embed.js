/* SearchCenter web-embed chunk — lazy-loaded via ScChunkLoader */
const SC_WEB_BOOKMARK_LABELS_KEY = "sc_web_bookmark_labels_v1";
const SC_WEB_BROADCAST_SITES_KEY = "sc_web_broadcast_sites_v1";
const SC_WEB_EMBED_COL_WIDTHS_KEY = "sc_web_embed_col_widths_v1";
const SC_WEB_EMBED_COL_MIN_WIDTH = 280;
const SC_WEB_EMBED_COL_MIN_WIDTH_FIT = 200;
const SC_WEB_EMBED_COL_DEFAULT_WIDTH = 390;
const SC_WEB_EMBED_COL_GAP = 8;
const SC_WEB_EMBED_MAX_COLUMNS = 8;

const WEB_EMBED_ID_ALIASES = Object.freeze({
  qwen: "qianwen",
  tongyi: "qianwen"
});

function scWebEmbedMakeSite(id, label, homeUrl, opts) {
  return Object.assign({
    id: id,
    label: label,
    homeUrl: homeUrl,
    embedEnabled: true,
    defaultOpen: false,
    iconKey: id,
    kind: "chat",
    queryMode: "inject",
    uaMode: "mobile",
    profileMode: "shared",
    embedRisk: "untested",
    submitDelayMs: 0
  }, opts || {});
}

const SC_WEB_EMBED_SITES = Object.freeze([
  scWebEmbedMakeSite("deepseek", "DeepSeek", "https://chat.deepseek.com/", { defaultOpen: true, embedRisk: "none", submitDelayMs: 550 }),
  scWebEmbedMakeSite("doubao", "豆包", "https://www.doubao.com/chat/", { defaultOpen: true, embedRisk: "none" }),
  scWebEmbedMakeSite("gemini", "Gemini", "https://gemini.google.com/app", { defaultOpen: true, uaMode: "desktop", embedRisk: "login", submitDelayMs: 550 }),
  scWebEmbedMakeSite("grok", "Grok", "https://grok.com/", { defaultOpen: true, queryMode: "url", uaMode: "desktop", embedRisk: "none" }),
  scWebEmbedMakeSite("perplexity", "Perplexity", "https://www.perplexity.ai/", { defaultOpen: true, kind: "search", queryMode: "url", uaMode: "desktop", profileMode: "isolated", embedRisk: "none" }),
  scWebEmbedMakeSite("kimi", "Kimi", "https://kimi.moonshot.cn/", { embedRisk: "none" }),
  scWebEmbedMakeSite("claude", "Claude", "https://claude.ai/", { uaMode: "desktop", embedRisk: "login" }),
  scWebEmbedMakeSite("yuanbao", "元宝", "https://yuanbao.tencent.com/", { embedRisk: "none" }),
  scWebEmbedMakeSite("aistudio", "AI Studio", "https://aistudio.google.com/", { iconKey: "gemini", uaMode: "desktop", embedRisk: "login" }),
  scWebEmbedMakeSite("nami", "纳米 AI", "https://www.n.cn/", { kind: "search", queryMode: "url", uaMode: "desktop" }),
  scWebEmbedMakeSite("mita", "秘塔", "https://metaso.cn/", { kind: "search", queryMode: "url", uaMode: "desktop", embedRisk: "none" }),
  scWebEmbedMakeSite("qianwen", "千问", "https://tongyi.aliyun.com/qianwen/", { iconKey: "qwen", embedRisk: "none" }),
  scWebEmbedMakeSite("copilot", "Copilot", "https://copilot.microsoft.com/", { uaMode: "desktop", embedRisk: "login" }),
  scWebEmbedMakeSite("lmarena", "LMArena", "https://lmarena.ai/", { uaMode: "desktop" }),
  scWebEmbedMakeSite("manus", "Manus", "https://manus.im/", { uaMode: "desktop" }),
  scWebEmbedMakeSite("mistral", "Mistral", "https://chat.mistral.ai/", { uaMode: "desktop" }),
  scWebEmbedMakeSite("yupp", "Yupp", "https://yupp.ai/", { uaMode: "desktop" }),
  scWebEmbedMakeSite("zai", "Z.ai", "https://z.ai/", { uaMode: "desktop" }),
  scWebEmbedMakeSite("coze", "扣子", "https://www.coze.cn/", { embedRisk: "none" }),
  scWebEmbedMakeSite("tiangong", "天工", "https://www.tiangong.cn/", { uaMode: "desktop" }),
  scWebEmbedMakeSite("wenxin", "文心一言", "https://yiyan.baidu.com/", { embedRisk: "none" })
]);

function normalizeWebEmbedSiteId(rawId) {
  const s = String(rawId || "").trim().toLowerCase();
  return WEB_EMBED_ID_ALIASES[s] || s;
}

function findWebEmbedSite(siteId) {
  const id = normalizeWebEmbedSiteId(siteId);
  return SC_WEB_EMBED_SITES.find((s) => s.id === id) || null;
}

function isWebEmbedSiteEnabled(site) {
  if (!site) return false;
  if (site.embedEnabled === false) return false;
  if (site.enabled === false) return false;
  return true;
}

function getWebEmbedPoolSites() {
  return SC_WEB_EMBED_SITES.filter(isWebEmbedSiteEnabled);
}

function getWebEmbedDefaultOpenSiteIds() {
  const pool = getWebEmbedPoolSites();
  const defs = pool.filter((s) => s.defaultOpen).map((s) => s.id);
  return defs.length ? defs : (pool[0] ? [pool[0].id] : ["deepseek"]);
}

function normalizeWebEmbedBroadcastSites(rawIds) {
  const allowed = new Set(getWebEmbedPoolSites().map((s) => s.id));
  const base = Array.isArray(rawIds) && rawIds.length
    ? rawIds.map(normalizeWebEmbedSiteId)
    : getWebEmbedDefaultOpenSiteIds();
  const result = [];
  for (const id of base) {
    if (!allowed.has(id)) continue;
    if (result.includes(id)) continue;
    result.push(id);
    if (result.length >= SC_WEB_EMBED_MAX_COLUMNS) break;
  }
  return result.length ? result : getWebEmbedDefaultOpenSiteIds();
}

function validateWebEmbedCatalog() {
  const ids = SC_WEB_EMBED_SITES.map((s) => s.id);
  const duplicated = ids.filter((id, i) => ids.indexOf(id) !== i);
  const missingDefault = getWebEmbedDefaultOpenSiteIds().filter((id) => !ids.includes(id));
  const missingHome = SC_WEB_EMBED_SITES.filter((s) => !s.homeUrl).map((s) => s.id);
  if (duplicated.length || missingDefault.length || missingHome.length) {
    scWebEmbedDebugLog("warn", "catalog validate dup=" + duplicated.join(",") + " missingDefault=" + missingDefault.join(",") + " missingHome=" + missingHome.join(","));
  }
}

function webEmbedAssetUrl(relPath) {
  const p = String(relPath || "").replace(/^\/+/, "");
  return "https://app.local/assets/" + p;
}

function webEmbedSiteIconCandidates(siteOrId) {
  const site = typeof siteOrId === "object" ? siteOrId : findWebEmbedSite(siteOrId);
  const id = site ? site.id : normalizeWebEmbedSiteId(siteOrId);
  const iconKey = site && site.iconKey ? site.iconKey : id;
  const urls = [];
  const fromEngine = (state.engines || []).find((e) => normalizeWebEmbedSiteId(e && e.value) === id);
  if (fromEngine && fromEngine.iconUrl) urls.push(String(fromEngine.iconUrl));
  const names = [iconKey, id];
  const exts = [".svg", ".png", ".webp", ".jpg", ".jpeg"];
  for (const name of names) {
    if (!name) continue;
    for (const ext of exts) {
      urls.push(webEmbedAssetUrl("icons/ai/" + name + ext));
      urls.push(webEmbedAssetUrl("icons/app/" + name + ext));
    }
  }
  urls.push(webEmbedAssetUrl("icons/app/chat-ai-fallback.svg"));
  const seen = new Set();
  return urls.filter((u) => {
    if (!u || seen.has(u)) return false;
    seen.add(u);
    return true;
  });
}

function mountWebChipIcon(btn, site) {
  const meta = typeof site === "object" ? site : findWebEmbedSite(site);
  const urls = webEmbedSiteIconCandidates(meta || site);
  let idx = 0;
  const showFallback = () => {
    if (btn.querySelector(".web-chip-fallback")) return;
    const fb = document.createElement("span");
    fb.className = "web-chip-fallback";
    fb.textContent = String((meta && meta.label) || site.label || site.id || site || "?").slice(0, 1).toUpperCase();
    btn.insertBefore(fb, btn.firstChild);
  };
  const tryNext = () => {
    if (idx >= urls.length) {
      showFallback();
      return;
    }
    const img = document.createElement("img");
    img.className = "web-chip-icon";
    img.alt = "";
    img.src = urls[idx++];
    img.addEventListener("error", () => {
      img.remove();
      tryNext();
    });
    btn.insertBefore(img, btn.firstChild);
  };
  tryNext();
}

function isWebEmbedCategory() {
  return String(state.currentCategoryKey || "").toLowerCase() === "ai";
}

function isWebEmbedActive() {
  return getUIMode() === "web" && isWebEmbedCategory();
}

function getWebEmbedLayoutSites() {
  const list = getWebEmbedBroadcastSites();
  return list.length ? list.slice(0, SC_WEB_EMBED_MAX_COLUMNS) : defaultWebEmbedBroadcastSites();
}

function loadWebEmbedColumnWidthsPref() {
  try {
    const raw = localStorage.getItem(SC_WEB_EMBED_COL_WIDTHS_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch (_) {}
  return {};
}

function saveWebEmbedColumnWidthsPref(map) {
  try {
    localStorage.setItem(SC_WEB_EMBED_COL_WIDTHS_KEY, JSON.stringify(map && typeof map === "object" ? map : {}));
  } catch (_) {}
}

let _scWebEmbedColumnWidths = loadWebEmbedColumnWidthsPref();
let _scWebEmbedAutoFitWidths = null;
let _scWebEmbedAutoFitKey = "";
let _scWebEmbedAutoFitDisabled = true;

function clampWebEmbedColumnWidth(widthPx, allowFitMin) {
  const minW = allowFitMin ? SC_WEB_EMBED_COL_MIN_WIDTH_FIT : SC_WEB_EMBED_COL_MIN_WIDTH;
  return Math.max(minW, Math.round(Number(widthPx) || SC_WEB_EMBED_COL_DEFAULT_WIDTH));
}

function getWebEmbedStoredColumnWidth(siteId) {
  const id = String(siteId || "").trim();
  const saved = _scWebEmbedColumnWidths[id];
  if (saved && Number(saved) >= SC_WEB_EMBED_COL_MIN_WIDTH) return clampWebEmbedColumnWidth(saved);
  return SC_WEB_EMBED_COL_DEFAULT_WIDTH;
}

function refreshWebEmbedAutoFit(forceResetScroll) {
  _scWebEmbedAutoFitWidths = null;
  _scWebEmbedAutoFitKey = "";
  return false;
}

function getWebEmbedColumnWidth(siteId) {
  const id = String(siteId || "").trim();
  if (_scWebEmbedAutoFitWidths && _scWebEmbedAutoFitWidths[id])
    return _scWebEmbedAutoFitWidths[id];
  return getWebEmbedStoredColumnWidth(id);
}

function setWebEmbedColumnWidth(siteId, widthPx, persist) {
  const id = String(siteId || "").trim();
  if (!id) return;
  if (persist) {
    _scWebEmbedAutoFitDisabled = true;
    _scWebEmbedAutoFitWidths = null;
    _scWebEmbedAutoFitKey = "";
  }
  _scWebEmbedColumnWidths[id] = clampWebEmbedColumnWidth(widthPx);
  if (persist) saveWebEmbedColumnWidthsPref(_scWebEmbedColumnWidths);
}

function getWebEmbedViewportWidthPx() {
  const viewport = document.getElementById("web-embed-scroll-viewport");
  return viewport ? Math.max(0, Math.round(viewport.clientWidth || 0)) : 0;
}

function getWebEmbedMaxScrollPx() {
  const vpW = getWebEmbedViewportWidthPx();
  const stripW = getWebEmbedStripWidth(getWebEmbedLayoutSites());
  return Math.max(0, stripW - vpW);
}

function webEmbedNeedsHorizontalScroll(siteIds) {
  const ids = siteIds || getWebEmbedLayoutSites();
  if (!ids.length) return false;
  return getWebEmbedStripWidth(ids) > getWebEmbedViewportWidthPx() + 1;
}

function healWebEmbedColumnWidthsForScroll(siteIds) {
  const ids = siteIds || getWebEmbedLayoutSites();
  if (!ids.length || !webEmbedNeedsHorizontalScroll(ids)) return false;
  let healed = false;
  ids.forEach((id, index) => {
    const saved = Number(_scWebEmbedColumnWidths[id]);
    if (!Number.isFinite(saved) || saved < SC_WEB_EMBED_COL_DEFAULT_WIDTH) {
      _scWebEmbedColumnWidths[id] = SC_WEB_EMBED_COL_DEFAULT_WIDTH;
      healed = true;
    } else if (ids.length > 1 && index === ids.length - 1 && saved > SC_WEB_EMBED_COL_DEFAULT_WIDTH + 100) {
      _scWebEmbedColumnWidths[id] = SC_WEB_EMBED_COL_DEFAULT_WIDTH;
      healed = true;
    }
  });
  if (healed) saveWebEmbedColumnWidthsPref(_scWebEmbedColumnWidths);
  return healed;
}

function getWebEmbedTrackWidthPx() {
  const viewport = document.getElementById("web-embed-scroll-viewport");
  const siteIds = getWebEmbedLayoutSites();
  const contentW = getWebEmbedStripWidth(siteIds) + getWebEmbedViewportFillExtra();
  const vpW = viewport ? Math.max(0, Math.round(viewport.clientWidth || 0)) : 0;
  return Math.max(vpW, contentW, 1);
}

function syncWebEmbedViewportScroll(resetWhenFit) {
  const viewport = document.getElementById("web-embed-scroll-viewport");
  if (!viewport) return;
  const fit = !webEmbedNeedsHorizontalScroll()
    && (getWebEmbedViewportFillExtra() > 0
      || getWebEmbedStripWidth(getWebEmbedLayoutSites()) <= getWebEmbedViewportWidthPx() + 1);
  if (resetWhenFit && fit) {
    if ((viewport.scrollLeft || 0) > 0) viewport.scrollLeft = 0;
    return;
  }
  const maxScroll = getWebEmbedMaxScrollPx();
  if ((viewport.scrollLeft || 0) > maxScroll) viewport.scrollLeft = maxScroll;
}

function getWebEmbedViewportFillExtra() {
  const viewport = document.getElementById("web-embed-scroll-viewport");
  const siteIds = getWebEmbedLayoutSites();
  if (!viewport || !siteIds.length) return 0;
  if (siteIds.length > 1) return 0;
  if (webEmbedNeedsHorizontalScroll(siteIds)) return 0;
  const strip = getWebEmbedStripWidth(siteIds);
  const vp = Math.max(0, Math.round(viewport.clientWidth || 0));
  return (vp > strip + 1) ? Math.max(0, vp - strip) : 0;
}

function getWebEmbedLayoutColumnWidth(siteId, siteIndex) {
  const w = getWebEmbedColumnWidth(siteId);
  const sites = getWebEmbedLayoutSites();
  const extra = getWebEmbedViewportFillExtra();
  if (extra > 0 && siteIndex === sites.length - 1) return w + extra;
  return w;
}

function getWebEmbedStripWidth(siteIds) {
  const ids = siteIds || [];
  if (!ids.length) return 0;
  const gaps = Math.max(0, ids.length - 1) * SC_WEB_EMBED_COL_GAP;
  return ids.reduce((sum, sid) => sum + getWebEmbedColumnWidth(sid), 0) + gaps;
}

function buildWebEmbedColumnLayoutPayload() {
  refreshWebEmbedAutoFit(false);
  const viewport = document.getElementById("web-embed-scroll-viewport");
  syncWebEmbedViewportScroll(false);
  const siteIds = getWebEmbedLayoutSites();
  const fillExtra = getWebEmbedViewportFillExtra();
  const vpW = getWebEmbedViewportWidthPx();
  const stripW = getWebEmbedStripWidth(siteIds);
  const maxScroll = Math.max(0, stripW - vpW);
  const scrollX = viewport ? Math.min(Math.max(0, Math.round(viewport.scrollLeft || 0)), maxScroll) : 0;
  return {
    scrollX,
    viewportWidth: vpW,
    stripWidth: stripW,
    columns: siteIds.map((id) => ({
      id,
      width: getWebEmbedColumnWidth(id)
    })),
    fillExtra
  };
}

function postWebEmbedColumnLayout(force) {
  if (!isWebEmbedActive() || _scWebEmbedLayoutFromHost) return;
  const layout = buildWebEmbedColumnLayoutPayload();
  const key = layout.scrollX + "|" + layout.columns.map((c) => c.id + ":" + c.width).join(",");
  if (!force && key === _scWebEmbedLastLayoutKey) return;
  _scWebEmbedLastLayoutKey = key;
  postToAhk({ type: "webLlmColumnLayout", columnLayout: layout });
}

function renderWebEmbedColumnTrack() {
  refreshWebEmbedAutoFit(true);
  const track = document.getElementById("web-embed-scroll-track");
  if (!track) return;
  const siteIds = getWebEmbedLayoutSites();
  healWebEmbedColumnWidthsForScroll(siteIds);
  track.innerHTML = "";
  track.style.width = getWebEmbedTrackWidthPx() + "px";
  siteIds.forEach((siteId, index) => {
    const meta = SC_WEB_EMBED_SITES.find((s) => s.id === siteId);
    const slot = document.createElement("div");
    slot.className = "web-embed-column-slot";
    slot.setAttribute("data-site", siteId);
    slot.style.width = getWebEmbedLayoutColumnWidth(siteId, index) + "px";
    const label = document.createElement("div");
    label.className = "web-embed-column-label";
    label.textContent = meta ? meta.label : siteId;
    slot.appendChild(label);
    track.appendChild(slot);
    if (index < siteIds.length - 1) {
      const gap = document.createElement("div");
      gap.className = "web-embed-column-gap";
      gap.style.width = SC_WEB_EMBED_COL_GAP + "px";
      gap.setAttribute("aria-hidden", "true");
      track.appendChild(gap);
    }
  });
  _scWebEmbedLastLayoutKey = "";
  if (!_scWebEmbedLayoutFromHost) postWebEmbedColumnLayout(true);
  renderWebEmbedTabBar();
  animateWebEmbedFocusFrame(getWebEmbedActiveEngine(), true);
  syncWebEmbedHScrollUi();
}

function syncWebEmbedColumnSlotWidths(columns) {
  if (!Array.isArray(columns) || !columns.length) return;
  const track = document.getElementById("web-embed-scroll-track");
  if (!track) return;
  columns.forEach((col) => {
    const id = String(col && col.id || "").trim();
    if (!id) return;
    if (col.width != null) setWebEmbedColumnWidth(id, col.width, false);
    const sites = getWebEmbedLayoutSites();
    const idx = sites.indexOf(id);
    const slot = track.querySelector('.web-embed-column-slot[data-site="' + id + '"]');
    if (slot) slot.style.width = getWebEmbedLayoutColumnWidth(id, idx >= 0 ? idx : 0) + "px";
  });
  track.style.width = getWebEmbedTrackWidthPx() + "px";
  syncWebEmbedHScrollUi();
  syncWebEmbedViewportScroll(true);
}

function applyWebLlmColumnLayoutState(payload) {
  if (!payload || !Array.isArray(payload.columns)) return;
  _scWebEmbedLayoutFromHost = true;
  try {
    const fillExtra = Math.max(0, Number(payload.fillExtra) || 0);
    for (const col of payload.columns) {
      const id = String(col && col.id || "").trim();
      if (!id) continue;
      let w = Number(col.width);
      if (!Number.isFinite(w)) w = getWebEmbedColumnWidth(id);
      const sites = getWebEmbedLayoutSites();
      const isLast = sites.length && id === sites[sites.length - 1];
      if (isLast && fillExtra > 0) w = Math.max(SC_WEB_EMBED_COL_MIN_WIDTH, w - fillExtra);
      setWebEmbedColumnWidth(id, w, false);
    }
    if (payload.scrollX != null) {
      const viewport = document.getElementById("web-embed-scroll-viewport");
      if (viewport) {
        const target = Math.max(0, Math.round(Number(payload.scrollX) || 0));
        if (Math.abs((viewport.scrollLeft || 0) - target) > 1)
          viewport.scrollLeft = target;
      }
    }
    syncWebEmbedHScrollUi();
    if (payload.dragging) {
      syncWebEmbedColumnSlotWidths(payload.columns);
      document.body.classList.add("sc-web-embed-col-resizing");
    } else {
      document.body.classList.remove("sc-web-embed-col-resizing");
      syncWebEmbedColumnSlotWidths(payload.columns);
    }
    if (isWebEmbedActive()) {
      animateWebEmbedFocusFrame(getWebEmbedActiveEngine(), !!payload.dragging);
    }
    if (payload.persist) saveWebEmbedColumnWidthsPref(_scWebEmbedColumnWidths);
  } finally {
    _scWebEmbedLayoutFromHost = false;
  }
}

function getWebEmbedActiveEngine() {
  const sid = String(state.webEmbedSiteId || "").trim();
  if (sid) return sid;
  const row = document.querySelector(".sc-web-ai-row.active");
  const fromRow = row ? String(row.getAttribute("data-site") || "").trim() : "";
  if (fromRow) return fromRow;
  const chip = document.querySelector(".webllm-site-chip.active, .web-embed-tab.active");
  const fromChip = chip ? String(chip.getAttribute("data-site") || "").trim() : "";
  if (fromChip) return fromChip;
  const list = getWebEmbedBroadcastSites();
  if (list.length) return list[0];
  return "deepseek";
}

function defaultWebEmbedBroadcastSites() {
  return normalizeWebEmbedBroadcastSites(null);
}

function loadWebEmbedBroadcastSitesPref() {
  try {
    const raw = localStorage.getItem(SC_WEB_BROADCAST_SITES_KEY);
    if (!raw) return defaultWebEmbedBroadcastSites();
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return defaultWebEmbedBroadcastSites();
    return normalizeWebEmbedBroadcastSites(parsed);
  } catch (_) {}
  return defaultWebEmbedBroadcastSites();
}

function saveWebEmbedBroadcastSitesPref(list) {
  try {
    localStorage.setItem(SC_WEB_BROADCAST_SITES_KEY, JSON.stringify(normalizeWebEmbedBroadcastSites(list)));
  } catch (_) {}
}

function getWebEmbedBroadcastSites() {
  if (Array.isArray(state.webEmbedBroadcastSites) && state.webEmbedBroadcastSites.length)
    return normalizeWebEmbedBroadcastSites(state.webEmbedBroadcastSites);
  return loadWebEmbedBroadcastSitesPref();
}

let _scWebEmbedFocusAnim = 0;
let _scWebEmbedFocusState = { left: 0, width: 0, leftV: 0, widthV: 0, siteId: "" };

function ensureWebEmbedFocusFrame() {
  const track = document.getElementById("web-embed-scroll-track");
  if (!track) return null;
  let frame = document.getElementById("web-embed-focus-frame");
  if (!frame) {
    frame = document.createElement("div");
    frame.id = "web-embed-focus-frame";
    frame.className = "web-embed-focus-frame";
    frame.setAttribute("aria-hidden", "true");
    track.appendChild(frame);
  }
  if (!frame.querySelector(".web-embed-focus-frame__halo-left")) {
    frame.innerHTML =
      '<div class="web-embed-focus-frame__glass"></div>' +
      '<div class="web-embed-focus-frame__halo web-embed-focus-frame__halo-left"></div>' +
      '<div class="web-embed-focus-frame__halo web-embed-focus-frame__halo-right"></div>';
  }
  return frame;
}

function getWebEmbedColumnSlotMetrics(siteId) {
  const track = document.getElementById("web-embed-scroll-track");
  const slot = document.querySelector('.web-embed-column-slot[data-site="' + String(siteId || "") + '"]');
  if (!track || !slot) return null;
  const padX = 5;
  const padY = 6;
  const left = slot.offsetLeft + padX;
  const width = Math.max(28, slot.offsetWidth - padX * 2);
  const height = Math.max(0, track.clientHeight - padY * 2);
  return { left, width, top: padY, height };
}

function _scWebEmbedSpringStep(current, target, velocity, stiffness, damping, dt) {
  const accel = -stiffness * (current - target) - damping * velocity;
  velocity += accel * dt;
  current += velocity * dt;
  return { current, velocity };
}

function animateWebEmbedFocusFrame(siteId, immediate) {
  const frame = ensureWebEmbedFocusFrame();
  if (!frame) return;
  const sid = String(siteId || "").trim();
  if (!sid || !isWebEmbedActive()) {
    frame.classList.remove("is-visible", "is-settled");
    if (_scWebEmbedFocusAnim) {
      cancelAnimationFrame(_scWebEmbedFocusAnim);
      _scWebEmbedFocusAnim = 0;
    }
    _scWebEmbedFocusState.siteId = "";
    return;
  }
  const metrics = getWebEmbedColumnSlotMetrics(sid);
  if (!metrics) return;
  const targetLeft = metrics.left;
  const targetWidth = metrics.width;
  const targetTop = metrics.top;
  const targetHeight = metrics.height;

  const applyMetrics = (left, width, settled) => {
    frame.style.left = Math.round(left) + "px";
    frame.style.width = Math.round(width) + "px";
    frame.style.top = targetTop + "px";
    frame.style.height = targetHeight + "px";
    frame.classList.add("is-visible");
    frame.classList.toggle("is-settled", !!settled);
  };

  if (immediate || !_scWebEmbedFocusState.siteId) {
    if (_scWebEmbedFocusAnim) {
      cancelAnimationFrame(_scWebEmbedFocusAnim);
      _scWebEmbedFocusAnim = 0;
    }
    _scWebEmbedFocusState = {
      left: targetLeft,
      width: targetWidth,
      leftV: 0,
      widthV: 0,
      siteId: sid
    };
    applyMetrics(targetLeft, targetWidth, true);
    return;
  }

  let animState = _scWebEmbedFocusState;
  animState.siteId = sid;
  const stiffness = immediate ? 280 : 164;
  const damping = immediate ? 32 : 30;
  let lastTs = 0;

  const tick = (ts) => {
    if (!lastTs) lastTs = ts;
    const dt = Math.min(0.034, (ts - lastTs) / 1000);
    lastTs = ts;

    const leftStep = _scWebEmbedSpringStep(animState.left, targetLeft, animState.leftV || 0, stiffness, damping, dt);
    const widthStep = _scWebEmbedSpringStep(animState.width, targetWidth, animState.widthV || 0, stiffness, damping, dt);
    animState.left = leftStep.current;
    animState.leftV = leftStep.velocity;
    animState.width = widthStep.current;
    animState.widthV = widthStep.velocity;

    const done = Math.abs(animState.left - targetLeft) < 0.45
      && Math.abs(animState.width - targetWidth) < 0.45
      && Math.abs(animState.leftV) < 1.8
      && Math.abs(animState.widthV) < 1.8;

    if (done) {
      animState.left = targetLeft;
      animState.width = targetWidth;
      animState.leftV = 0;
      animState.widthV = 0;
      _scWebEmbedFocusState = animState;
      applyMetrics(targetLeft, targetWidth, true);
      _scWebEmbedFocusAnim = 0;
      return;
    }

    applyMetrics(animState.left, animState.width, false);
    _scWebEmbedFocusAnim = requestAnimationFrame(tick);
  };

  if (_scWebEmbedFocusAnim) cancelAnimationFrame(_scWebEmbedFocusAnim);
  frame.classList.remove("is-settled");
  _scWebEmbedFocusAnim = requestAnimationFrame(tick);
}

function syncWebEmbedColumnFocus(immediate) {
  const focus = getWebEmbedActiveEngine();
  document.querySelectorAll(".web-embed-column-slot").forEach((slot) => {
    const sid = String(slot.getAttribute("data-site") || "");
    slot.classList.toggle("focus-active", sid === focus);
  });
  animateWebEmbedFocusFrame(focus, immediate !== false);
}

function syncWebEmbedTabBar(immediateIndicator) {
  const focus = getWebEmbedActiveEngine();
  const broadcast = new Set(getWebEmbedBroadcastSites());
  const chromeMap = (state.webEmbedSiteChrome && typeof state.webEmbedSiteChrome === "object")
    ? state.webEmbedSiteChrome
    : {};
  document.querySelectorAll(".web-embed-tab, .webllm-site-chip, .sc-web-ai-row").forEach((btn) => {
    const sid = String(btn.getAttribute("data-site") || "");
    const on = broadcast.has(sid);
    const isFocus = sid === focus;
    const chrome = chromeMap[sid] || {};
    const loading = isFocus && !!chrome.loading;
    btn.classList.toggle("active", isFocus);
    btn.classList.toggle("is-loading", loading);
    btn.classList.toggle("broadcast-on", on);
    btn.classList.toggle("broadcast-off", !on);
    btn.setAttribute("aria-selected", isFocus ? "true" : "false");
    btn.tabIndex = isFocus ? 0 : -1;
    const meta = SC_WEB_EMBED_SITES.find((s) => s.id === sid);
    const label = meta ? meta.label : sid;
    btn.title = label + (on ? " · 已参与同问" : " · 未参与同问") + "（点击切换，Ctrl+点击增删同问）";
    const closeBtn = btn.querySelector(".web-embed-tab-close");
    if (closeBtn) {
      const canClose = broadcast.size > 1;
      closeBtn.disabled = !canClose;
      closeBtn.title = canClose ? ("关闭 " + label) : "至少保留一个 AI 页面";
    }
    const sub = btn.querySelector(".web-chip-sub, .sc-web-ai-row__sub");
    if (sub && btn.classList.contains("web-embed-tab")) {
      if (loading) sub.textContent = "加载中…";
      else if (isFocus && (chrome.title || chrome.url)) sub.textContent = chrome.title || chrome.url;
      else sub.textContent = "";
      if (sub.classList.contains("web-chip-sub")) sub.hidden = !sub.textContent;
    }
  });
  syncWebEmbedColumnFocus(true);
  syncWebEmbedOmnibarBadge(focus);
  animateWebEmbedTabIndicator(focus, !!immediateIndicator);
  syncWebModeNavAiRows();
}

const SC_WEB_EMBED_INPUT_HINT = "输入问题，向所有AI提问";

function syncWebEmbedOmnibarChips(siteId) {
  const host = document.getElementById("web-embed-omnibar-chips");
  if (!host) return;
  if (!isWebEmbedActive()) {
    host.innerHTML = "";
    host.hidden = true;
    return;
  }
  const focus = String(siteId || getWebEmbedActiveEngine() || "").trim();
  const sites = getWebEmbedLayoutSites();
  if (!sites.length) {
    host.innerHTML = "";
    host.hidden = true;
    return;
  }
  host.hidden = false;
  host.setAttribute("aria-hidden", "false");
  const existing = new Map();
  host.querySelectorAll(".web-embed-omnibar-chip").forEach((btn) => {
    existing.set(String(btn.getAttribute("data-site") || ""), btn);
  });
  const nextIds = sites.slice();
  host.querySelectorAll(".web-embed-omnibar-chip").forEach((btn) => {
    const sid = String(btn.getAttribute("data-site") || "");
    if (!nextIds.includes(sid)) btn.remove();
  });
  nextIds.forEach((sid) => {
    const site = SC_WEB_EMBED_SITES.find((s) => s.id === sid);
    if (!site) return;
    const isActive = sid === focus;
    let btn = existing.get(sid);
    if (!btn) {
      btn = document.createElement("button");
      btn.type = "button";
      btn.className = "web-embed-omnibar-chip";
      btn.setAttribute("data-site", sid);
      btn.addEventListener("click", (e) => {
        if (e.ctrlKey || e.metaKey) {
          toggleWebEmbedBroadcastSite(sid);
          return;
        }
        setWebEmbedFocusSite(sid, true);
      });
      host.appendChild(btn);
    }
    btn.className = "web-embed-omnibar-chip" + (isActive ? " is-active" : " is-icon-only");
    btn.title = site.label + "（点击切换，Ctrl+点击增删同问）";
    btn.setAttribute("aria-pressed", isActive ? "true" : "false");
    btn.innerHTML = "";
    const iconWrap = document.createElement("span");
    iconWrap.className = "web-embed-omnibar-chip__icon";
    mountWebChipIcon(iconWrap, site);
    btn.appendChild(iconWrap);
    if (isActive) {
      const label = document.createElement("span");
      label.className = "web-embed-omnibar-chip__label";
      label.textContent = site.label;
      btn.appendChild(label);
    }
  });
}

function syncWebEmbedOmnibarBadge(siteId) {
  syncWebEmbedOmnibarChips(siteId);
}

function applyScCpuUsage(payload) {
  const pctRaw = Number(payload && payload.percent);
  const pct = Number.isFinite(pctRaw) ? Math.max(0, Math.min(100, pctRaw)) : 0;
  const gauge = document.getElementById("sc-cpu-gauge");
  const cap = document.getElementById("sc-cpu-cap");
  if (!gauge) return;
  gauge.style.setProperty("--cpu-pct", String(Math.round(pct)));
  gauge.classList.remove("level-ok", "level-warn", "level-hot");
  if (pct <= 10) gauge.classList.add("level-ok");
  else if (pct <= 30) gauge.classList.add("level-warn");
  else gauge.classList.add("level-hot");
  if (cap) cap.textContent = "CPU " + (Number.isFinite(pctRaw) ? pct.toFixed(pct >= 10 ? 0 : 1) : "—") + "%";
  gauge.title = "搜索中心 CPU " + (Number.isFinite(pctRaw) ? pct + "%" : "—");
}

let _scWebEmbedTabIndAnim = 0;
let _scWebEmbedTabIndState = { left: 0, width: 0, top: 0, height: 0, leftV: 0, widthV: 0, topV: 0, heightV: 0, siteId: "", vertical: false };

function isWebEmbedNavTabsVertical() {
  const host = document.getElementById("webllm-site-chips");
  return !!(host && host.classList.contains("sc-web-nav-tabs"));
}

function getWebEmbedTabMetrics(siteId) {
  const host = document.getElementById("webllm-site-chips");
  const inner = host
    ? (host.closest(".sc-web-nav-tabs-inner") || host.closest(".web-embed-tabbar-inner"))
    : null;
  const btn = host ? host.querySelector('.web-embed-tab[data-site="' + String(siteId || "") + '"], .webllm-site-chip[data-site="' + String(siteId || "") + '"]') : null;
  if (!inner || !btn) return null;
  const innerRect = inner.getBoundingClientRect();
  const btnRect = btn.getBoundingClientRect();
  const pad = 2;
  if (isWebEmbedNavTabsVertical()) {
    return {
      vertical: true,
      top: btnRect.top - innerRect.top + pad,
      height: Math.max(28, btnRect.height - pad * 2),
      left: pad,
      width: Math.max(28, innerRect.width - pad * 2)
    };
  }
  return {
    vertical: false,
    left: btnRect.left - innerRect.left + pad,
    width: Math.max(28, btnRect.width - pad * 2),
    top: pad,
    height: Math.max(28, innerRect.height - pad * 2)
  };
}

function animateWebEmbedTabIndicator(siteId, immediate) {
  const indicator = document.getElementById("web-embed-tab-indicator");
  if (!indicator) return;
  const sid = String(siteId || "").trim();
  if (!sid || !isWebEmbedActive()) {
    indicator.classList.remove("is-visible", "is-settled");
    if (_scWebEmbedTabIndAnim) {
      cancelAnimationFrame(_scWebEmbedTabIndAnim);
      _scWebEmbedTabIndAnim = 0;
    }
    _scWebEmbedTabIndState.siteId = "";
    return;
  }
  const metrics = getWebEmbedTabMetrics(sid);
  if (!metrics) return;
  const vertical = !!metrics.vertical;
  const targetLeft = metrics.left;
  const targetWidth = metrics.width;
  const targetTop = metrics.top;
  const targetHeight = metrics.height;

  const apply = (left, width, top, height, settled) => {
    if (vertical) {
      indicator.style.top = Math.round(top) + "px";
      indicator.style.height = Math.round(height) + "px";
      indicator.style.left = Math.round(left) + "px";
      indicator.style.right = "";
      indicator.style.width = "auto";
    } else {
      indicator.style.left = Math.round(left) + "px";
      indicator.style.width = Math.round(width) + "px";
      indicator.style.top = Math.round(top) + "px";
      indicator.style.height = Math.round(height) + "px";
      indicator.style.right = "";
    }
    indicator.classList.add("is-visible");
    indicator.classList.toggle("is-settled", !!settled);
  };

  if (immediate || !_scWebEmbedTabIndState.siteId) {
    if (_scWebEmbedTabIndAnim) {
      cancelAnimationFrame(_scWebEmbedTabIndAnim);
      _scWebEmbedTabIndAnim = 0;
    }
    _scWebEmbedTabIndState = {
      left: targetLeft,
      width: targetWidth,
      top: targetTop,
      height: targetHeight,
      leftV: 0,
      widthV: 0,
      topV: 0,
      heightV: 0,
      siteId: sid,
      vertical
    };
    apply(targetLeft, targetWidth, targetTop, targetHeight, true);
    return;
  }

  let anim = _scWebEmbedTabIndState;
  anim.siteId = sid;
  anim.vertical = vertical;
  const stiffness = immediate ? 300 : 210;
  const damping = immediate ? 32 : 26;
  let lastTs = 0;

  const tick = (ts) => {
    if (!lastTs) lastTs = ts;
    const dt = Math.min(0.034, (ts - lastTs) / 1000);
    lastTs = ts;
    let done = false;
    if (vertical) {
      const topStep = _scWebEmbedSpringStep(anim.top, targetTop, anim.topV || 0, stiffness, damping, dt);
      const heightStep = _scWebEmbedSpringStep(anim.height, targetHeight, anim.heightV || 0, stiffness, damping, dt);
      anim.top = topStep.current;
      anim.topV = topStep.velocity;
      anim.height = heightStep.current;
      anim.heightV = heightStep.velocity;
      anim.left = targetLeft;
      anim.width = targetWidth;
      done = Math.abs(anim.top - targetTop) < 0.45
        && Math.abs(anim.height - targetHeight) < 0.45
        && Math.abs(anim.topV) < 1.8
        && Math.abs(anim.heightV) < 1.8;
    } else {
      const leftStep = _scWebEmbedSpringStep(anim.left, targetLeft, anim.leftV || 0, stiffness, damping, dt);
      const widthStep = _scWebEmbedSpringStep(anim.width, targetWidth, anim.widthV || 0, stiffness, damping, dt);
      anim.left = leftStep.current;
      anim.leftV = leftStep.velocity;
      anim.width = widthStep.current;
      anim.widthV = widthStep.velocity;
      anim.top = targetTop;
      anim.height = targetHeight;
      done = Math.abs(anim.left - targetLeft) < 0.45
        && Math.abs(anim.width - targetWidth) < 0.45
        && Math.abs(anim.leftV) < 1.8
        && Math.abs(anim.widthV) < 1.8;
    }
    if (done) {
      anim.left = targetLeft;
      anim.width = targetWidth;
      anim.top = targetTop;
      anim.height = targetHeight;
      anim.leftV = 0;
      anim.widthV = 0;
      anim.topV = 0;
      anim.heightV = 0;
      _scWebEmbedTabIndState = anim;
      apply(targetLeft, targetWidth, targetTop, targetHeight, true);
      _scWebEmbedTabIndAnim = 0;
      return;
    }
    apply(anim.left, anim.width, anim.top, anim.height, false);
    _scWebEmbedTabIndAnim = requestAnimationFrame(tick);
  };

  if (_scWebEmbedTabIndAnim) cancelAnimationFrame(_scWebEmbedTabIndAnim);
  indicator.classList.remove("is-settled");
  _scWebEmbedTabIndAnim = requestAnimationFrame(tick);
}

let _scWebEmbedLastBroadcastSyncKey = "";
let _scWebEmbedLayoutBootstrapped = false;

function syncWebEmbedBroadcastUi(postHost = false, rebuildTrack = false) {
  const broadcast = new Set(normalizeWebEmbedBroadcastSites(getWebEmbedBroadcastSites()));
  state.webEmbedBroadcastSites = Array.from(broadcast);
  syncWebEmbedTabBar();
  state.selectedEngines = state.webEmbedBroadcastSites.slice();
  if (rebuildTrack && isWebEmbedActive()) renderWebEmbedColumnTrack();
  if (postHost) {
    const syncKey = state.selectedEngines.join(",");
    if (syncKey !== _scWebEmbedLastBroadcastSyncKey) {
      _scWebEmbedLastBroadcastSyncKey = syncKey;
      postToAhk({ type: "syncSelectedEngines", selectedEngines: state.selectedEngines.slice() });
      scWebEmbedDebugLog("info", "syncSelectedEngines → [" + state.selectedEngines.join(",") + "]");
    }
    if (isWebEmbedActive()) {
      postToAhk({ type: "webLlmColumnLayout", columnLayout: buildWebEmbedColumnLayoutPayload() });
    }
  }
}

function scrollWebEmbedColumnIntoView(siteId, postLayout = false) {
  const viewport = document.getElementById("web-embed-scroll-viewport");
  if (!viewport) return;
  const sites = getWebEmbedLayoutSites();
  const idx = sites.indexOf(String(siteId || ""));
  if (idx < 0) return;
  healWebEmbedColumnWidthsForScroll(sites);
  const fit = !webEmbedNeedsHorizontalScroll(sites)
    && (getWebEmbedViewportFillExtra() > 0
      || getWebEmbedStripWidth(sites) <= getWebEmbedViewportWidthPx() + 1);
  if (fit) {
    if ((viewport.scrollLeft || 0) > 0) viewport.scrollLeft = 0;
    if (postLayout) postWebEmbedColumnLayout(true);
    return;
  }
  let x = 0;
  for (let i = 0; i < idx; i++) {
    x += getWebEmbedLayoutColumnWidth(sites[i], i) + SC_WEB_EMBED_COL_GAP;
  }
  const maxScroll = getWebEmbedMaxScrollPx();
  const target = Math.min(Math.max(0, x), maxScroll);
  if (Math.abs((viewport.scrollLeft || 0) - target) > 2) {
    // 与宿主 WebView 列同步须即时滚动；smooth 会导致 scrollX 滞后、页面只露出窄条
    viewport.scrollLeft = target;
  }
  syncWebEmbedHScrollUi();
  if (postLayout) {
    postWebEmbedColumnLayout(true);
    requestAnimationFrame(() => postWebEmbedColumnLayout(true));
  }
}

function focusAdjacentWebEmbedSite(delta) {
  const sites = getWebEmbedLayoutSites();
  if (sites.length < 2) return;
  const step = Number(delta) || 0;
  if (!step) return;
  const cur = getWebEmbedActiveEngine();
  let idx = sites.indexOf(cur);
  if (idx < 0) idx = 0;
  const nextIdx = (idx + step + sites.length * 8) % sites.length;
  setWebEmbedFocusSite(sites[nextIdx], true);
}

function postWebEmbedHostScroll(siteId, deltaCss, deltaCols) {
  if (siteId) {
    postToAhk({ type: "webLlmScroll", siteId: String(siteId) });
    return;
  }
  if (deltaCols != null && Number.isFinite(Number(deltaCols))) {
    postToAhk({ type: "webLlmScroll", adjacent: Math.round(Number(deltaCols)) });
    return;
  }
  if (deltaCss != null && Number.isFinite(Number(deltaCss))) {
    postToAhk({ type: "webLlmScroll", deltaCss: Math.round(Number(deltaCss)) });
  }
}

function setWebEmbedScrollPx(px, postHost = true, options = null) {
  const viewport = document.getElementById("web-embed-scroll-viewport");
  if (!viewport) return;
  const isDrag = !!(options && options.drag);
  const maxScroll = getWebEmbedMaxScrollPx();
  const target = Math.min(Math.max(0, Math.round(Number(px) || 0)), maxScroll);
  if (Math.abs((viewport.scrollLeft || 0) - target) > 1) viewport.scrollLeft = target;
  syncWebEmbedHScrollUi();
  if (!postHost || _scWebEmbedLayoutFromHost) return;
  const vpW = getWebEmbedViewportWidthPx();
  const stripW = getWebEmbedStripWidth(getWebEmbedLayoutSites());
  const payload = {
    type: "webLlmScroll",
    scrollX: target,
    viewportWidth: vpW,
    stripWidth: stripW
  };
  if (options && options.finalize) payload.finalize = true;
  flushWebEmbedScrollHostSync(payload);
  if (!isDrag && maxScroll > 0 && target >= maxScroll - 2) {
    const sites = getWebEmbedLayoutSites();
    const last = sites.length ? sites[sites.length - 1] : "";
    if (last) postToAhk({ type: "webLlmFocusSite", siteId: last });
  }
}

function syncWebEmbedHScrollUi() {
  const row = document.getElementById("web-embed-hscroll-row");
  const slider = document.getElementById("web-embed-hscroll-slider");
  const viewport = document.getElementById("web-embed-scroll-viewport");
  if (!row || !slider || !viewport) return;
  const show = isWebEmbedActive() && webEmbedNeedsHorizontalScroll();
  const wasShown = !row.classList.contains("hidden");
  row.classList.toggle("hidden", !show);
  if (wasShown !== show) scheduleWebEmbedContentRect(false);
  if (!show) return;
  const maxScroll = getWebEmbedMaxScrollPx();
  slider.max = String(maxScroll);
  slider.value = String(Math.min(Math.max(0, Math.round(viewport.scrollLeft || 0)), maxScroll));
  const prev = document.getElementById("web-embed-hscroll-prev");
  const next = document.getElementById("web-embed-hscroll-next");
  const cur = Number(slider.value) || 0;
  if (prev) prev.disabled = cur <= 0;
  if (next) next.disabled = cur >= maxScroll;
}

function initWebEmbedHScroll() {
  const slider = document.getElementById("web-embed-hscroll-slider");
  const prev = document.getElementById("web-embed-hscroll-prev");
  const next = document.getElementById("web-embed-hscroll-next");
  if (slider && slider.getAttribute("data-hscroll-ready") !== "1") {
    slider.setAttribute("data-hscroll-ready", "1");
    const endDrag = () => {
      _scWebEmbedHScrollDragging = false;
      setWebEmbedScrollPx(slider.value, true, { finalize: true });
    };
    slider.addEventListener("pointerdown", () => { _scWebEmbedHScrollDragging = true; });
    slider.addEventListener("pointerup", endDrag);
    slider.addEventListener("pointercancel", endDrag);
    slider.addEventListener("input", () => setWebEmbedScrollPx(slider.value, true, { drag: true }));
    slider.addEventListener("change", endDrag);
  }
  if (prev && prev.getAttribute("data-hscroll-ready") !== "1") {
    prev.setAttribute("data-hscroll-ready", "1");
    prev.addEventListener("click", (e) => {
      e.preventDefault();
      const viewport = document.getElementById("web-embed-scroll-viewport");
      const step = SC_WEB_EMBED_COL_DEFAULT_WIDTH + SC_WEB_EMBED_COL_GAP;
      setWebEmbedScrollPx((viewport ? viewport.scrollLeft : 0) - step, true);
    });
  }
  if (next && next.getAttribute("data-hscroll-ready") !== "1") {
    next.setAttribute("data-hscroll-ready", "1");
    next.addEventListener("click", (e) => {
      e.preventDefault();
      const viewport = document.getElementById("web-embed-scroll-viewport");
      const step = SC_WEB_EMBED_COL_DEFAULT_WIDTH + SC_WEB_EMBED_COL_GAP;
      setWebEmbedScrollPx((viewport ? viewport.scrollLeft : 0) + step, true);
    });
  }
}

function syncWebEmbedScrollNav() {
  const nav = document.getElementById("web-embed-tab-scroll-nav");
  if (!nav) return;
  const sites = getWebEmbedLayoutSites();
  const show = isWebEmbedActive() && sites.length > 1
    && (sites.length > 5 || webEmbedNeedsHorizontalScroll());
  nav.classList.toggle("hidden", !show);
  if (!show) return;
  const prev = document.getElementById("web-embed-scroll-prev");
  const next = document.getElementById("web-embed-scroll-next");
  if (prev) prev.disabled = false;
  if (next) next.disabled = false;
  syncWebEmbedHScrollUi();
}

function scrollWebEmbedNavTabIntoView(siteId) {
  const host = document.getElementById("webllm-site-chips");
  const scroll = document.getElementById("sc-web-nav-tabs-scroll");
  if (!host || !scroll || !isWebEmbedNavTabsVertical()) return;
  const btn = host.querySelector('.web-embed-tab[data-site="' + String(siteId || "") + '"], .webllm-site-chip[data-site="' + String(siteId || "") + '"]');
  if (!btn) return;
  const scrollRect = scroll.getBoundingClientRect();
  const btnRect = btn.getBoundingClientRect();
  if (btnRect.top < scrollRect.top + 4) {
    scroll.scrollTop -= (scrollRect.top + 4) - btnRect.top;
  } else if (btnRect.bottom > scrollRect.bottom - 4) {
    scroll.scrollTop += btnRect.bottom - (scrollRect.bottom - 4);
  }
}

function initWebEmbedScrollNav() {
  const navScroll = document.getElementById("sc-web-nav-tabs-scroll");
  const prev = document.getElementById("web-embed-scroll-prev");
  const next = document.getElementById("web-embed-scroll-next");
  if (prev && prev.getAttribute("data-scroll-ready") !== "1") {
    prev.setAttribute("data-scroll-ready", "1");
    prev.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      focusAdjacentWebEmbedSite(-1);
    });
  }
  if (next && next.getAttribute("data-scroll-ready") !== "1") {
    next.setAttribute("data-scroll-ready", "1");
    next.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      focusAdjacentWebEmbedSite(1);
    });
  }
  if (navScroll && navScroll.getAttribute("data-wheel-ready") !== "1") {
    navScroll.setAttribute("data-wheel-ready", "1");
    navScroll.addEventListener("wheel", (e) => {
      if (!isWebEmbedActive()) return;
      const sites = getWebEmbedLayoutSites();
      if (sites.length < 2) return;
      let step = 0;
      if (Math.abs(e.deltaY) >= 1) step = e.deltaY > 0 ? 1 : -1;
      else if (Math.abs(e.deltaX) >= 1) step = e.deltaX > 0 ? 1 : -1;
      if (!step) return;
      e.preventDefault();
      focusAdjacentWebEmbedSite(step);
    }, { passive: false });
  }
}

function setWebEmbedFocusSite(siteId, postHost = true) {
  const eng = String(siteId || "").trim();
  if (!eng) return;
  state.webEmbedSiteId = eng;
  syncWebEmbedTabBar(false);
  scrollWebEmbedNavTabIntoView(eng);
  if (isWebEmbedActive()) {
    if (healWebEmbedColumnWidthsForScroll()) {
      const track = document.getElementById("web-embed-scroll-track");
      if (track) {
        track.style.width = getWebEmbedTrackWidthPx() + "px";
        getWebEmbedLayoutSites().forEach((sid, index) => {
          const slot = track.querySelector('.web-embed-column-slot[data-site="' + sid + '"]');
          if (slot) slot.style.width = getWebEmbedLayoutColumnWidth(sid, index) + "px";
        });
      }
    }
    scrollWebEmbedColumnIntoView(eng, false);
    if (postHost) {
      const sites = getWebEmbedLayoutSites();
      const inLayout = sites.indexOf(eng) >= 0;
      if (!inLayout) {
        postToAhk({ type: "syncSelectedEngines", selectedEngines: sites.slice() });
      }
      postToAhk({ type: "webLlmFocusSite", siteId: eng });
    } else {
      scrollWebEmbedColumnIntoView(eng, true);
    }
    syncWebEmbedScrollNav();
  } else if (postHost) {
    postToAhk({ type: "webLlmFocusSite", siteId: eng });
  }
}

function toggleWebEmbedBroadcastSite(siteId) {
  const id = normalizeWebEmbedSiteId(siteId);
  if (!id) return;
  let list = normalizeWebEmbedBroadcastSites(getWebEmbedBroadcastSites());
  const i = list.indexOf(id);
  const wasAdd = i < 0;
  if (i >= 0) {
    if (list.length <= 1) {
      scWebEmbedDebugLog("warn", "无法移除最后一个 AI 页面: " + id);
      return;
    }
    list = list.filter((v) => v !== id);
    scWebEmbedDebugLog("info", "移除 AI 页面: " + id + " → [" + list.join(",") + "]");
  } else {
    if (list.length >= SC_WEB_EMBED_MAX_COLUMNS) {
      scWebEmbedDebugLog("warn", "已达最大列数 " + SC_WEB_EMBED_MAX_COLUMNS + "，请先关闭一个 AI 页面");
      try {
        if (typeof showToast === "function") showToast("已达最大列数 " + SC_WEB_EMBED_MAX_COLUMNS + "，请先关闭一个 AI 页面");
      } catch (_) {}
      return;
    }
    list = list.concat([id]);
    scWebEmbedDebugLog("info", "添加 AI 页面: " + id + " → [" + list.join(",") + "]");
  }
  state.webEmbedBroadcastSites = list;
  saveWebEmbedBroadcastSitesPref(list);
  syncWebEmbedBroadcastUi(true, true);
  renderWebModeNavBody();
  if (isWebEmbedActive() && wasAdd) setWebEmbedFocusSite(id, true);
}

function syncWebEmbedSelectedEngine(engineId, postHost = true) {
  setWebEmbedFocusSite(engineId, postHost);
}

function loadWebBookmarkLabelsPref() {
  try {
    const v = localStorage.getItem(SC_WEB_BOOKMARK_LABELS_KEY);
    if (v === "1") return true;
    if (v === "0") return false;
  } catch (_) {}
  return false;
}

function saveWebBookmarkLabelsPref(show) {
  try {
    localStorage.setItem(SC_WEB_BOOKMARK_LABELS_KEY, show ? "1" : "0");
  } catch (_) {}
}

function syncWebBookmarkLabelsUi() {
  const show = !!state.webBookmarkShowLabels;
  document.body.classList.toggle("web-bookmarks-hide-labels", !show);
  const btn = document.getElementById("web-bookmark-label-toggle");
  if (btn) {
    btn.setAttribute("aria-pressed", show ? "true" : "false");
    btn.title = show ? "隐藏站点名称" : "显示站点名称";
  }
}

function dismissWebEmbedHost(dispose = true) {
  cancelWebEmbedRectTimers();
  _scWebEmbedLastRectKey = "";
  _scWebEmbedHostBootstrapped = false;
  try { postToAhk({ type: "webLlmDismiss", dispose: !!dispose }); } catch (_) {}
}

function cancelWebEmbedRectTimers() {
  if (_scWebEmbedRectDebounce) {
    clearTimeout(_scWebEmbedRectDebounce);
    _scWebEmbedRectDebounce = 0;
  }
  _scWebEmbedRectRetries = 0;
}

function isWebEmbedComposeBottom() {
  return document.body.classList.contains("wb-ai-layout")
    || document.body.classList.contains("uwb-layout");
}

function ensureWebEmbedOmnibarUrlHost() {
  const slot = document.getElementById("web-embed-search-slot");
  if (!slot) return null;
  let host = document.getElementById("web-embed-omnibar-url");
  if (!host) {
    slot.innerHTML = "<div class=\"web-embed-omnibar-url-host\" id=\"web-embed-omnibar-url\" aria-live=\"polite\"></div>";
    host = document.getElementById("web-embed-omnibar-url");
  }
  return host;
}

function syncWebEmbedSearchDock(embed) {
  const box = document.getElementById("searchBoxInner");
  const anchor = document.getElementById("search-box-anchor");
  const slot = document.getElementById("web-embed-search-slot");
  const toolbar = document.getElementById("web-embed-toolbar");
  const workspace = document.getElementById("web-embed-workspace");
  const icon = document.getElementById("search-icon-inline");
  const composeBottom = isWebEmbedComposeBottom();
  if (composeBottom) {
    if (workspace && embed) workspace.classList.remove("hidden");
    if (box && anchor && box.parentElement !== anchor) anchor.appendChild(box);
    if (box) box.classList.remove("web-embed-search-compact");
    if (toolbar) toolbar.classList.remove("web-embed-toolbar-with-search");
    if (icon) icon.innerHTML = "&#127760;";
    const input = document.getElementById("search");
    if (input) input.removeAttribute("aria-label");
    if (embed) ensureWebEmbedOmnibarUrlHost();
    else if (slot) slot.innerHTML = "";
    if (embed) {
      scheduleWebEmbedContentRect();
      setTimeout(scheduleWebEmbedContentRect, 80);
      setTimeout(scheduleWebEmbedContentRect, 260);
    } else dismissWebEmbedHost();
    return;
  }
  if (!box || !anchor || !slot) return;
  if (workspace && embed) workspace.classList.remove("hidden");
  const target = embed ? slot : anchor;
  if (box.parentElement !== target) target.appendChild(box);
  box.classList.toggle("web-embed-search-compact", embed);
  if (toolbar) toolbar.classList.toggle("web-embed-toolbar-with-search", embed);
  if (icon) icon.innerHTML = embed ? "&#127760;" : "&#128269;";
  const input = document.getElementById("search");
  if (input) {
    if (embed) {
      input.setAttribute("rows", "1");
      input.setAttribute("aria-label", "地址栏");
    } else {
      input.removeAttribute("aria-label");
    }
  }
  if (embed) {
    scheduleWebEmbedContentRect();
  } else {
    dismissWebEmbedHost();
  }
}

function getWebEmbedComposeBottomEl() {
  if (!isWebEmbedComposeBottom()) return null;
  return document.querySelector("#wb-compose-bottom, .wb-compose-bottom, form.uwb-compose, #compose-form");
}

function getWebEmbedHostMeasureEl() {
  return document.getElementById("web-embed-host-frame")
    || document.getElementById("web-embed-scroll-viewport");
}

function getWebEmbedComposeReservePx() {
  const el = getWebEmbedComposeBottomEl();
  if (!el) return 0;
  const r = el.getBoundingClientRect();
  return Math.max(0, Math.round(r.height || el.offsetHeight || 0));
}

function clampWebEmbedHostRectToComposeBottom(rect) {
  if (!rect || !isWebEmbedComposeBottom()) return rect;
  const compose = getWebEmbedComposeBottomEl();
  if (!compose) return rect;
  const cb = compose.getBoundingClientRect();
  const top = Number(rect.top) || 0;
  let maxBottom = top + (Number(rect.height) || 0);
  if (cb.top > top + 40) {
    maxBottom = Math.min(maxBottom, cb.top - 2);
  }
  const nextH = Math.max(0, Math.round(maxBottom - top));
  if (nextH < 80) return rect;
  if (nextH >= (Number(rect.height) || 0)) return rect;
  return Object.assign({}, rect, { height: nextH });
}

function measureWebEmbedHostRect() {
  const measureEl = getWebEmbedHostMeasureEl();
  const viewport = document.getElementById("web-embed-scroll-viewport");
  const ws = document.getElementById("web-embed-workspace");
  if (!measureEl || !ws || ws.classList.contains("hidden")) return null;
  const box = measureEl.getBoundingClientRect();
  const cs = getComputedStyle(measureEl);
  const borderL = parseFloat(cs.borderLeftWidth) || 0;
  const borderT = parseFloat(cs.borderTopWidth) || 0;
  const borderB = parseFloat(cs.borderBottomWidth) || 0;
  const width = Math.max(0, Math.round((viewport && viewport.clientWidth) ? viewport.clientWidth : measureEl.clientWidth || 0));
  let top = Math.round(box.top + borderT);
  let height = Math.max(0, Math.round(measureEl.clientHeight || 0));
  if (height < 80 && box.height > 0) {
    height = Math.max(0, Math.round(box.height - borderT - borderB));
  }
  if (isWebEmbedComposeBottom()) {
    const compose = getWebEmbedComposeBottomEl();
    const toolbar = document.getElementById("web-embed-toolbar");
    const anchorTop = toolbar ? Math.round(toolbar.getBoundingClientRect().bottom) : top;
    const stage = document.getElementById("wb-stage");
    if (stage) {
      const sb = stage.getBoundingClientRect();
      if (sb.bottom > anchorTop + 40) {
        const stageCap = Math.round(sb.bottom - anchorTop - 4);
        if (stageCap >= 100) {
          top = anchorTop;
          height = Math.min(height, stageCap);
        }
      }
    }
    if (compose) {
      const cb = compose.getBoundingClientRect();
      if (cb.top > anchorTop + 8) {
        const capH = Math.round(cb.top - anchorTop - 4);
        if (capH >= 100) {
          top = anchorTop;
          height = Math.min(height, capH);
        }
      }
    }
  }
  if (width < 140 || height < 100) return null;
  return clampWebEmbedHostRectToComposeBottom({
    left: box.left + borderL,
    top,
    width,
    height
  });
}

let _scWebEmbedLayoutRo = null;
function ensureWebEmbedLayoutObserver() {
  if (_scWebEmbedLayoutRo) return;
  const ws = document.getElementById("web-embed-workspace");
  if (!ws || typeof ResizeObserver !== "function") return;
  _scWebEmbedLayoutRo = new ResizeObserver(() => {
    scheduleWebEmbedContentRect();
    if (isWebEmbedActive()) syncWebEmbedHScrollUi();
  });
  _scWebEmbedLayoutRo.observe(ws);
  const frame = document.getElementById("web-embed-scroll-viewport");
  if (frame) _scWebEmbedLayoutRo.observe(frame);
  const hostFrame = document.getElementById("web-embed-host-frame");
  if (hostFrame) _scWebEmbedLayoutRo.observe(hostFrame);
  const track = document.getElementById("web-embed-scroll-track");
  if (track) _scWebEmbedLayoutRo.observe(track);
  const bar = document.getElementById("web-embed-toolbar");
  if (bar) _scWebEmbedLayoutRo.observe(bar);
  const compose = getWebEmbedComposeBottomEl();
  if (compose) _scWebEmbedLayoutRo.observe(compose);
  const nav = document.getElementById("sc-mode-nav");
  if (nav) _scWebEmbedLayoutRo.observe(nav);
  const stage = document.getElementById("wb-stage");
  if (stage) _scWebEmbedLayoutRo.observe(stage);
  const debugPanel = document.getElementById("web-embed-debug-panel");
  if (debugPanel) _scWebEmbedLayoutRo.observe(debugPanel);
}

let _scWebEmbedRectRetries = 0;
let _scWebEmbedRectDebounce = 0;
let _scWebEmbedLastRectKey = "";
let _scWebEmbedLastLayoutKey = "";
let _scWebEmbedLayoutFromHost = false;
let _scWebEmbedHostBootstrapped = false;
let _scWebEmbedHScrollDragging = false;
let _scWebEmbedScrollHostRaf = 0;
let _scWebEmbedScrollHostPending = null;

function scheduleWebEmbedScrollHostSync(payload) {
  _scWebEmbedScrollHostPending = payload;
  if (_scWebEmbedScrollHostRaf) return;
  _scWebEmbedScrollHostRaf = requestAnimationFrame(() => {
    _scWebEmbedScrollHostRaf = 0;
    const p = _scWebEmbedScrollHostPending;
    _scWebEmbedScrollHostPending = null;
    if (p && !_scWebEmbedLayoutFromHost) postToAhk(p);
  });
}

function flushWebEmbedScrollHostSync(payload) {
  if (_scWebEmbedScrollHostRaf) {
    cancelAnimationFrame(_scWebEmbedScrollHostRaf);
    _scWebEmbedScrollHostRaf = 0;
  }
  _scWebEmbedScrollHostPending = null;
  if (payload && !_scWebEmbedLayoutFromHost) postToAhk(payload);
}

function scheduleWebEmbedContentRect() {
  if (!isWebEmbedActive()) return;
  if (_scWebEmbedRectDebounce) return;
  _scWebEmbedRectDebounce = setTimeout(() => {
    _scWebEmbedRectDebounce = 0;
    requestAnimationFrame(() => {
      postWebEmbedContentRect();
    });
  }, 120);
}

function syncWebEmbedToolbarVisibility() {
  const bar = document.getElementById("web-embed-toolbar");
  if (!bar) return;
  const embed = isWebEmbedActive();
  bar.classList.toggle("hidden", !embed);
  if (embed) bar.classList.remove("hidden");
}

function syncWebEmbedLayout() {
  const embed = isWebEmbedActive();
  const mode = getUIMode();
  document.body.classList.toggle("sc-web-embed-layout", embed);
  document.body.classList.toggle("sc-web-mode-layout", mode === "web");
  syncWebEmbedDebugStatusBar();
  const layout = document.getElementById("layout");
  if (layout) layout.classList.toggle("sc-web-embed-active", embed);
  const ws = document.getElementById("web-embed-workspace");
  if (ws) ws.classList.toggle("hidden", !embed);
  const setup = document.getElementById("web-embed-setup");
  if (setup) {
    if (embed) {
      if (!setup.hasAttribute("data-user-toggled")) setup.open = false;
    } else if (!setup.hasAttribute("data-user-toggled")) {
      setup.open = true;
    }
  }
  syncWebEmbedSearchDock(embed);
  syncWebEmbedToolbarVisibility();
  syncWebBookmarkLabelsUi();
  if (embed) {
    if (!Array.isArray(state.webEmbedBroadcastSites) || !state.webEmbedBroadcastSites.length)
      state.webEmbedBroadcastSites = loadWebEmbedBroadcastSitesPref();
    state.selectedEngines = state.webEmbedBroadcastSites.slice();
    if (!_scWebEmbedLayoutBootstrapped) {
      _scWebEmbedLayoutBootstrapped = true;
      saveWebEmbedBroadcastSitesPref(state.webEmbedBroadcastSites);
      renderWebEmbedColumnTrack();
      renderWebEmbedTabBar();
      syncWebEmbedBroadcastUi(true);
      ensureWebEmbedLayoutObserver();
      scheduleWebEmbedContentRect();
      setTimeout(scheduleWebEmbedContentRect, 120);
      setTimeout(scheduleWebEmbedContentRect, 300);
      if (!String(state.webEmbedSiteId || "").trim())
        setWebEmbedFocusSite(getWebEmbedActiveEngine(), true);
    } else {
      renderWebEmbedTabBar();
      syncWebEmbedHScrollUi();
      syncWebEmbedScrollNav();
    }
    syncWebEmbedViewportScroll(false);
  } else {
    _scWebEmbedLayoutBootstrapped = false;
  }
  if (mode === "web" && !embed) renderWebExternalHint();
  if (mode === "web") {
    renderWebModeNavBody();
    renderEngines();
  }
}

function buildWebExternalEmptyStateHtml() {
  const engines = Array.isArray(state.selectedEngines) ? state.selectedEngines.filter(Boolean) : [];
  const names = engines.map((v) => {
    const row = (state.engines || []).find((e) => String(e && e.value || "") === String(v));
    return row && row.name ? String(row.name) : String(v);
  });
  const engLine = names.length
    ? ("当前引擎：" + names.join("、"))
    : "请先在上方展开「分类与搜索引擎」并选择引擎";
  return "<div class=\"empty web-mode-hint\">" + escapeHtml(engLine)
    + "<br>输入关键词后按 Enter 或点「搜索」，将在系统浏览器打开。</div>";
}

function renderWebExternalHint() {
  if (getUIMode() !== "web" || isWebEmbedActive()) return;
  const list = document.getElementById("result-list");
  if (!list) return;
  list.innerHTML = buildWebExternalEmptyStateHtml();
  const count = document.getElementById("result-count");
  if (count) count.textContent = "外开搜索";
}

function postWebEmbedLayoutResync() {
  if (!isWebEmbedActive()) return;
  refreshWebEmbedAutoFit(true);
  syncWebEmbedViewportScroll(true);
  postWebEmbedColumnLayout(true);
  const measured = measureWebEmbedHostRect();
  const el = document.getElementById("web-embed-scroll-viewport");
  let r = measured;
  if (!r && el) {
    const box = el.getBoundingClientRect();
    const cs = getComputedStyle(el);
    const borderL = parseFloat(cs.borderLeftWidth) || 0;
    const borderT = parseFloat(cs.borderTopWidth) || 0;
    r = {
      left: box.left + borderL,
      top: box.top + borderT,
      width: Math.max(0, Math.round(el.clientWidth || 0)),
      height: Math.max(0, Math.round(el.clientHeight || 0))
    };
  }
  if (!r || r.width < 80 || r.height < 60) return;
  postToAhk({
    type: "webLlmContentRect",
    rect: {
      left: Math.round(r.left),
      top: Math.round(r.top),
      width: Math.max(200, Math.round(r.width)),
      height: Math.max(140, Math.round(r.height)),
      dpr: Number(window.devicePixelRatio) || 1
    },
    columnLayout: buildWebEmbedColumnLayoutPayload()
  });
}

function scheduleWebEmbedLayoutResync() {
  [280, 640].forEach((ms) => {
    setTimeout(() => {
      if (isWebEmbedActive()) postWebEmbedLayoutResync();
    }, ms);
  });
}

function postWebEmbedContentRect(force) {
  if (!isWebEmbedActive()) return;
  const measured = measureWebEmbedHostRect();
  const el = getWebEmbedHostMeasureEl();
  let r = measured;
  if (!r && el) {
    const box = el.getBoundingClientRect();
    const cs = getComputedStyle(el);
    const borderL = parseFloat(cs.borderLeftWidth) || 0;
    const borderT = parseFloat(cs.borderTopWidth) || 0;
    const borderB = parseFloat(cs.borderBottomWidth) || 0;
    r = clampWebEmbedHostRectToComposeBottom({
      left: box.left + borderL,
      top: box.top + borderT,
      width: Math.max(0, Math.round(el.clientWidth || 0)),
      height: Math.max(0, Math.round(el.clientHeight || 0))
    });
    if (r && r.height < 80 && box.height > 0) {
      r.height = Math.max(0, Math.round(box.height - borderT - borderB));
      r = clampWebEmbedHostRectToComposeBottom(r);
    }
  }
  if (!r || r.width < 80 || r.height < 60) {
    if (_scWebEmbedRectRetries < 20) {
      _scWebEmbedRectRetries += 1;
      if (_scWebEmbedRectRetries === 1 || _scWebEmbedRectRetries === 6 || _scWebEmbedRectRetries >= 20) {
        scWebEmbedDebugLog("warn", "内嵌视口矩形无效 " + (r ? (r.width + "×" + r.height) : "null") + " retry=" + _scWebEmbedRectRetries);
      }
      setTimeout(scheduleWebEmbedContentRect, _scWebEmbedRectRetries < 6 ? 80 : 200);
    }
    return;
  }
  _scWebEmbedRectRetries = 0;
  refreshWebEmbedAutoFit(true);
  const key = [Math.round(r.left), Math.round(r.top), Math.round(r.width), Math.round(r.height)].join("x");
  const rectPayload = {
    left: Math.round(r.left),
    top: Math.round(r.top),
    width: Math.max(200, Math.round(r.width)),
    height: Math.max(140, Math.round(r.height)),
    dpr: Number(window.devicePixelRatio) || 1,
    composeBottom: !!isWebEmbedComposeBottom(),
    composeReservePx: getWebEmbedComposeReservePx()
  };
  const layoutPayload = buildWebEmbedColumnLayoutPayload();
  if (!force && key === _scWebEmbedLastRectKey) {
    syncWebEmbedViewportScroll(true);
    postWebEmbedColumnLayout(true);
    postToAhk({
      type: "webLlmContentRect",
      rect: rectPayload,
      columnLayout: layoutPayload
    });
    return;
  }
  _scWebEmbedLastRectKey = key;
  syncWebEmbedViewportScroll(true);
  if (_scWebEmbedHostBootstrapped && !force) {
    postToAhk({
      type: "webLlmContentRect",
      rect: rectPayload,
      columnLayout: layoutPayload
    });
    scheduleWebEmbedLayoutResync();
    return;
  }
  _scWebEmbedHostBootstrapped = true;
  scWebEmbedDebugLog("info", "webLlmBootstrap " + rectPayload.width + "×" + rectPayload.height + " sites=[" + getWebEmbedLayoutSites().join(",") + "]");
  postToAhk({
    type: "webLlmBootstrap",
    rect: rectPayload,
    selectedEngines: getWebEmbedLayoutSites().slice(),
    columnLayout: layoutPayload
  });
  scheduleWebEmbedLayoutResync();
}

function applyWebLlmChromeState(payload) {
  if (!payload || typeof payload !== "object") return;
  const back = document.getElementById("webllm-btn-back");
  const fwd = document.getElementById("webllm-btn-forward");
  const status = document.getElementById("webllm-status");
  if (back) back.disabled = !payload.canGoBack;
  if (fwd) fwd.disabled = !payload.canGoForward;
  const title = String(payload.title || "").trim();
  const url = String(payload.url || "").trim();
  const loading = !!payload.loading;
  if (status) status.textContent = loading ? "加载中…" : (title || url || "多栏移动版 · 点击书签切换焦点");
  const urlHost = document.getElementById("web-embed-omnibar-url");
  if (urlHost && isWebEmbedComposeBottom()) {
    urlHost.textContent = loading ? "加载中…" : (url || title || "—");
    urlHost.title = url || title || "";
  }
  const input = document.getElementById("search");
  if (input && isWebEmbedActive() && !String(input.value || "").trim()) {
    input.placeholder = SC_WEB_EMBED_INPUT_HINT;
  }
  const sid = String(payload.siteId || "").trim();
  if (sid) {
    if (!state.webEmbedSiteChrome || typeof state.webEmbedSiteChrome !== "object")
      state.webEmbedSiteChrome = {};
    state.webEmbedSiteChrome[sid] = { loading, title, url };
  }
  syncWebEmbedTabBar(false);
  const cur = String(state.webEmbedSiteId || "").trim();
  if (sid && sid !== cur) setWebEmbedFocusSite(sid, false);
}

function isWebEmbedSidebarNav() {
  const host = document.getElementById("webllm-site-chips");
  return !!(host && host.classList.contains("sc-web-nav-tabs"));
}

function webEmbedSiteRoleLabel(site) {
  if (!site) return "联网问答";
  const kind = String(site.kind || "chat").toLowerCase();
  if (kind === "search") return "联网搜索";
  return "联网问答";
}

function bindWebEmbedAiNavRowActions(row, site) {
  row.addEventListener("click", (e) => {
    if (!isWebEmbedSiteEnabled(site)) return;
    e.preventDefault();
    e.stopPropagation();
    if (e.ctrlKey || e.metaKey) {
      toggleWebEmbedBroadcastSite(site.id);
      return;
    }
    if (getUIMode() !== "web") {
      if (typeof setUIMode === "function") setUIMode("web", true);
    }
    if (!isWebEmbedCategory()) {
      if (typeof selectCategoryLocal === "function") selectCategoryLocal("ai", true);
    }
    setWebEmbedFocusSite(site.id, true);
  });
}

function createWebEmbedAiNavRow(site) {
  const row = document.createElement("button");
  row.type = "button";
  row.className = "sc-web-ai-row";
  row.setAttribute("data-site", site.id);
  row.setAttribute("role", "tab");
  row.innerHTML =
    "<span class=\"sc-web-ai-row__icon\"></span>" +
    "<span class=\"sc-web-ai-row__main\">" +
      "<span class=\"sc-web-ai-row__title\"></span>" +
      "<span class=\"sc-web-ai-row__sub\"></span>" +
      "<span class=\"sc-web-ai-row__progress\"><span class=\"sc-web-ai-row__progress-fill\"></span></span>" +
    "</span>" +
    "<span class=\"sc-web-ai-row__dot\" aria-hidden=\"true\"></span>";
  const iconHost = row.querySelector(".sc-web-ai-row__icon");
  if (iconHost) mountWebChipIcon(iconHost, site);
  const titleEl = row.querySelector(".sc-web-ai-row__title");
  if (titleEl) titleEl.textContent = site.label + " - " + webEmbedSiteRoleLabel(site);
  bindWebEmbedAiNavRowActions(row, site);
  return row;
}

function renderWebEmbedAiNavRows() {
  const host = document.getElementById("webllm-site-chips");
  if (!host || !isWebEmbedSidebarNav()) return false;
  const layoutSites = getWebEmbedLayoutSites();
  const existing = new Map();
  host.querySelectorAll(".sc-web-ai-row").forEach((row) => {
    existing.set(String(row.getAttribute("data-site") || ""), row);
  });
  host.querySelectorAll(".sc-web-ai-row").forEach((row) => {
    const sid = String(row.getAttribute("data-site") || "");
    if (!layoutSites.includes(sid)) row.remove();
  });
  layoutSites.forEach((siteId) => {
    const site = SC_WEB_EMBED_SITES.find((s) => s.id === siteId);
    if (!site) return;
    let row = existing.get(site.id);
    if (!row) {
      row = createWebEmbedAiNavRow(site);
      host.appendChild(row);
    } else {
      const titleEl = row.querySelector(".sc-web-ai-row__title");
      if (titleEl) titleEl.textContent = site.label + " - " + webEmbedSiteRoleLabel(site);
      row.disabled = !isWebEmbedSiteEnabled(site);
    }
  });
  host.querySelectorAll(".web-embed-tab, .webllm-site-chip").forEach((el) => el.remove());
  const indicator = document.getElementById("web-embed-tab-indicator");
  if (indicator) indicator.style.display = "none";
  updateWebEmbedAiCount();
  syncWebModeNavAiRows();
  return true;
}

function renderWebEmbedTabBar() {
  const card = document.querySelector('.sc-mode-card[data-mode="web"]');
  if (card) {
    const body = card.querySelector(".sc-mode-card-body");
    if (body) ensureWebModeNavBodyShell(body);
  }
  if (isWebEmbedSidebarNav() && renderWebEmbedAiNavRows()) {
    if (!Array.isArray(state.webEmbedBroadcastSites) || !state.webEmbedBroadcastSites.length) {
      state.webEmbedBroadcastSites = loadWebEmbedBroadcastSitesPref();
    }
    syncWebEmbedTabBar(true);
    syncWebEmbedScrollNav();
    return;
  }
  const host = document.getElementById("webllm-site-chips");
  if (!host) return;
  const layoutSites = getWebEmbedLayoutSites();
  const existing = new Map();
  host.querySelectorAll(".web-embed-tab, .webllm-site-chip").forEach((btn) => {
    existing.set(String(btn.getAttribute("data-site") || ""), btn);
  });
  const nextIds = layoutSites.slice();
  host.querySelectorAll(".web-embed-tab, .webllm-site-chip").forEach((btn) => {
    const sid = String(btn.getAttribute("data-site") || "");
    if (!nextIds.includes(sid)) btn.remove();
  });
  nextIds.forEach((siteId) => {
    const site = SC_WEB_EMBED_SITES.find((s) => s.id === siteId);
    if (!site) return;
    let btn = existing.get(site.id);
    if (!btn) {
      btn = document.createElement("button");
      btn.type = "button";
      btn.className = "web-embed-tab";
      btn.setAttribute("data-site", site.id);
      btn.setAttribute("role", "tab");
      mountWebChipIcon(btn, site);
      const textWrap = document.createElement("span");
      textWrap.className = "web-chip-text";
      const label = document.createElement("span");
      label.className = "web-chip-label";
      label.textContent = site.label;
      const sub = document.createElement("span");
      sub.className = "web-chip-sub";
      sub.hidden = true;
      textWrap.appendChild(label);
      textWrap.appendChild(sub);
      btn.appendChild(textWrap);
      const closeBtn = document.createElement("button");
      closeBtn.type = "button";
      closeBtn.className = "web-embed-tab-close";
      closeBtn.setAttribute("aria-label", "关闭 " + site.label);
      closeBtn.innerHTML = "×";
      closeBtn.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        if (getWebEmbedBroadcastSites().length <= 1) return;
        toggleWebEmbedBroadcastSite(site.id);
      });
      btn.appendChild(closeBtn);
      btn.addEventListener("click", (e) => {
        if (!isWebEmbedSiteEnabled(site)) return;
        e.preventDefault();
        e.stopPropagation();
        if (e.ctrlKey || e.metaKey) {
          toggleWebEmbedBroadcastSite(site.id);
          return;
        }
        setWebEmbedFocusSite(site.id, true);
      });
      host.appendChild(btn);
    } else {
      const label = btn.querySelector(".web-chip-label");
      if (label) label.textContent = site.label;
      if (!btn.querySelector(".web-chip-text")) {
        const plainLabel = btn.querySelector(".web-chip-label");
        if (plainLabel && plainLabel.parentElement === btn) {
          const textWrap = document.createElement("span");
          textWrap.className = "web-chip-text";
          plainLabel.parentNode.insertBefore(textWrap, plainLabel);
          textWrap.appendChild(plainLabel);
          const sub = document.createElement("span");
          sub.className = "web-chip-sub";
          sub.hidden = true;
          textWrap.appendChild(sub);
        }
      }
      if (!btn.querySelector(".web-embed-tab-close")) {
        const closeBtn = document.createElement("button");
        closeBtn.type = "button";
        closeBtn.className = "web-embed-tab-close";
        closeBtn.setAttribute("aria-label", "关闭 " + site.label);
        closeBtn.innerHTML = "×";
        closeBtn.addEventListener("click", (e) => {
          e.preventDefault();
          e.stopPropagation();
          if (getWebEmbedBroadcastSites().length <= 1) return;
          toggleWebEmbedBroadcastSite(site.id);
        });
        btn.appendChild(closeBtn);
      }
      btn.classList.add("web-embed-tab");
      btn.disabled = !isWebEmbedSiteEnabled(site);
    }
  });
  if (!Array.isArray(state.webEmbedBroadcastSites) || !state.webEmbedBroadcastSites.length) {
    state.webEmbedBroadcastSites = loadWebEmbedBroadcastSitesPref();
  }
  syncWebEmbedTabBar(true);
  syncWebEmbedScrollNav();
}

function ensureWebEmbedTabScrollSync() {
  const scroll = document.getElementById("sc-web-nav-tabs-scroll");
  const host = document.getElementById("webllm-site-chips");
  const target = scroll || host;
  if (!target || target.getAttribute("data-tab-scroll-ready") === "1") return;
  target.setAttribute("data-tab-scroll-ready", "1");
  target.addEventListener("scroll", () => {
    if (isWebEmbedActive() && _scWebEmbedTabIndState.siteId) {
      animateWebEmbedTabIndicator(_scWebEmbedTabIndState.siteId, true);
    }
  }, { passive: true });
}

function renderWebLlmToolbar() {
  validateWebEmbedCatalog();
  renderWebEmbedTabBar();
}

const _scWebEmbedDebugEvents = [];
const _scWebEmbedDebugState = { open: false, logTab: "js", hostSnap: null, pollTimer: 0 };

function scWebEmbedDebugLog(level, msg) {
  const line = "[" + new Date().toLocaleTimeString() + "][" + String(level || "info") + "] " + String(msg || "");
  _scWebEmbedDebugEvents.push(line);
  if (_scWebEmbedDebugEvents.length > 120) _scWebEmbedDebugEvents.shift();
  if (_scWebEmbedDebugState.open) renderWebEmbedDebugLogPane();
}

function buildWebEmbedClientDebugSnapshot() {
  const viewport = document.getElementById("web-embed-scroll-viewport");
  const ws = document.getElementById("web-embed-workspace");
  const measured = measureWebEmbedHostRect();
  const vpRect = viewport ? viewport.getBoundingClientRect() : null;
  return {
    mode: getUIMode(),
    category: String(state.currentCategoryKey || ""),
    embedActive: isWebEmbedActive(),
    broadcastSites: getWebEmbedBroadcastSites().slice(),
    layoutSites: getWebEmbedLayoutSites().slice(),
    focusSite: String(state.webEmbedSiteId || ""),
    hostRectNull: !measured,
    hostRect: measured,
    viewport: viewport ? {
      clientW: viewport.clientWidth,
      clientH: viewport.clientHeight,
      scrollW: viewport.scrollWidth,
      scrollLeft: viewport.scrollLeft,
      boxW: vpRect ? Math.round(vpRect.width) : 0,
      boxH: vpRect ? Math.round(vpRect.height) : 0
    } : null,
    workspaceHidden: !!(ws && ws.classList.contains("hidden")),
    hostBootstrapped: !!_scWebEmbedHostBootstrapped,
    lastRectKey: String(_scWebEmbedLastRectKey || "")
  };
}

function syncWebEmbedDebugStatusBar() {
  const grp = document.getElementById("sc-status-group-web-debug");
  if (!grp) return;
  grp.classList.toggle("hidden", getUIMode() !== "web");
}

function renderWebEmbedDebugIssues(issues) {
  const host = document.getElementById("web-embed-debug-issues");
  if (!host) return;
  const list = Array.isArray(issues) ? issues : [];
  if (!list.length) {
    host.innerHTML = '<div class="web-embed-debug-issue level-ok">未发现明显异常 · 若仍无法加页，查看右侧日志</div>';
    return;
  }
  host.innerHTML = list.map((it) => {
    const lv = String(it && it.level || "warn");
    const msg = escapeHtml(String(it && it.msg || it && it.code || "?"));
    return '<div class="web-embed-debug-issue level-' + lv + '">' + msg + "</div>";
  }).join("");
}

function renderWebEmbedDebugKv(client, snap) {
  const host = document.getElementById("web-embed-debug-kv");
  if (!host) return;
  const flags = snap && snap.flags ? snap.flags : {};
  const rect = snap && snap.contentRect ? snap.contentRect : {};
  const rows = [
    ["页面模式", String(client.mode || "") + " / cat=" + String(client.category || "")],
    ["内嵌激活", client.embedActive ? "是" : "否"],
    ["页面 AI 列", (client.broadcastSites || []).join(", ") || "(空)"],
    ["宿主 engines", (snap && snap.selectedEngines || []).join(", ") || "(空)"],
    ["layoutIds", (snap && snap.layoutSiteIds || []).join(", ") || "(空)"],
    ["rectReady", flags.contentRectReady ? "是" : "否"],
    ["宿主 rect", (rect.width || 0) + "×" + (rect.height || 0)],
    ["页面 rect", client.hostRect ? (client.hostRect.width + "×" + client.hostRect.height) : "未测到"],
    ["bootstrap", "boot=" + (flags.embedBootstrapped ? "1" : "0") + " wait=" + (flags.bootstrapWaitCount || 0)],
    ["canBootstrap", flags.canBootstrap ? "是" : "否"]
  ];
  host.innerHTML = rows.map(([k, v]) => "<dt>" + escapeHtml(k) + "</dt><dd>" + escapeHtml(String(v)) + "</dd>").join("");
}

function renderWebEmbedDebugSites(snap) {
  const host = document.getElementById("web-embed-debug-sites");
  if (!host) return;
  const sites = snap && Array.isArray(snap.sites) ? snap.sites : [];
  if (!sites.length) {
    host.textContent = "无 layout 站点记录";
    return;
  }
  host.textContent = sites.map((s) => {
    const st = [];
    st.push(String(s.id || "?"));
    st.push(s.ready ? "ready" : (s.createInFlight ? "creating" : "missing"));
    if (s.createAgeMs) st.push(String(s.createAgeMs) + "ms");
    if (s.lastNavError) st.push("err:" + s.lastNavError);
    return st.join(" · ");
  }).join("\n");
}

function renderWebEmbedDebugLogPane() {
  const pre = document.getElementById("web-embed-debug-log");
  if (!pre) return;
  const tab = _scWebEmbedDebugState.logTab || "js";
  if (tab === "js") {
    pre.textContent = _scWebEmbedDebugEvents.length
      ? _scWebEmbedDebugEvents.join("\n")
      : "(暂无页面事件 — 尝试添加/切换 AI 页面后刷新)";
    pre.scrollTop = pre.scrollHeight;
    return;
  }
  const snap = _scWebEmbedDebugState.hostSnap;
  const logs = snap && snap.logs ? snap.logs : {};
  pre.textContent = String(logs[tab] || "(无日志)") || "(无日志)";
  pre.scrollTop = pre.scrollHeight;
}

function renderWebEmbedDebugPanel(client, snap) {
  _scWebEmbedDebugState.hostSnap = snap || null;
  renderWebEmbedDebugIssues(snap && snap.issues);
  renderWebEmbedDebugKv(client, snap);
  renderWebEmbedDebugSites(snap);
  renderWebEmbedDebugLogPane();
}

function requestWebEmbedDebugSnapshot() {
  const client = buildWebEmbedClientDebugSnapshot();
  scWebEmbedDebugLog("info", "请求宿主诊断快照…");
  try {
    postToAhk({ type: "webEmbedDebugRequest", client });
  } catch (e) {
    scWebEmbedDebugLog("error", "postToAhk 失败: " + (e && e.message ? e.message : e));
    renderWebEmbedDebugPanel(client, null);
  }
}

function buildWebEmbedDebugActionPayload() {
  const rect = measureWebEmbedHostRect();
  return {
    client: buildWebEmbedClientDebugSnapshot(),
    rect: rect || undefined,
    selectedEngines: getWebEmbedLayoutSites().slice(),
    columnLayout: buildWebEmbedColumnLayoutPayload()
  };
}

function toggleWebEmbedDebugPanel(forceOpen) {
  const panel = document.getElementById("web-embed-debug-panel");
  if (!panel) return;
  const next = typeof forceOpen === "boolean" ? forceOpen : !panel.classList.contains("hidden");
  _scWebEmbedDebugState.open = next;
  panel.classList.toggle("hidden", !next);
  document.body.classList.toggle("sc-web-embed-debug-open", next);
  if (next) {
    if (getUIMode() !== "web") setUIMode("web", true);
    if (!isWebEmbedCategory()) selectCategoryLocal("ai", true);
    requestWebEmbedDebugSnapshot();
    if (_scWebEmbedDebugState.pollTimer) clearInterval(_scWebEmbedDebugState.pollTimer);
    _scWebEmbedDebugState.pollTimer = setInterval(() => {
      if (!_scWebEmbedDebugState.open) return;
      requestWebEmbedDebugSnapshot();
    }, 2500);
  } else if (_scWebEmbedDebugState.pollTimer) {
    clearInterval(_scWebEmbedDebugState.pollTimer);
    _scWebEmbedDebugState.pollTimer = 0;
  }
}

function initWebEmbedDebugPanel() {
  syncWebEmbedDebugStatusBar();
  const bind = (id, fn) => {
    const el = document.getElementById(id);
    if (el) el.addEventListener("click", fn);
  };
  bind("webllm-btn-debug", () => toggleWebEmbedDebugPanel(true));
  bind("btn-web-embed-debug", () => toggleWebEmbedDebugPanel(true));
  bind("web-embed-debug-close", () => toggleWebEmbedDebugPanel(false));
  bind("web-embed-debug-refresh", () => requestWebEmbedDebugSnapshot());
  bind("web-embed-debug-rebootstrap", () => {
    _scWebEmbedHostBootstrapped = false;
    scWebEmbedDebugLog("info", "手动触发 webLlmBootstrap");
    scheduleWebEmbedContentRect(true);
    try {
      postToAhk({ type: "webEmbedDebugAction", action: "rebootstrap", ...buildWebEmbedDebugActionPayload() });
    } catch (e) {
      scWebEmbedDebugLog("error", "rebootstrap 发送失败");
    }
  });
  bind("web-embed-debug-copy", () => {
    try {
      postToAhk({ type: "webEmbedDebugAction", action: "copy_trace", client: buildWebEmbedClientDebugSnapshot() });
    } catch (_) {}
  });
  bind("web-embed-debug-open-log", () => {
    try { postToAhk({ type: "webEmbedDebugAction", action: "open_log_dir" }); } catch (_) {}
  });
  document.querySelectorAll("#web-embed-debug-log-tabs .web-embed-debug-log-tab").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.querySelectorAll("#web-embed-debug-log-tabs .web-embed-debug-log-tab").forEach((b) => {
        b.classList.toggle("is-active", b === btn);
      });
      _scWebEmbedDebugState.logTab = String(btn.getAttribute("data-log-tab") || "js");
      renderWebEmbedDebugLogPane();
    });
  });
}

function initWebLlmToolbar() {
  syncWebEmbedSearchDock(isWebEmbedActive());
  ensureWebEmbedTabScrollSync();
  initWebEmbedScrollNav();
  renderWebLlmToolbar();
  initWebEmbedColumnLayout();
  const map = {
    "webllm-btn-back": "back",
    "webllm-btn-forward": "forward",
    "webllm-btn-reload": "reload",
    "webllm-btn-reload-all": "reload_all",
    "webllm-btn-home": "home",
    "webllm-btn-copyurl": "copyurl"
  };
  Object.keys(map).forEach((id) => {
    const el = document.getElementById(id);
    if (!el) return;
    el.addEventListener("click", () => postToAhk({ type: "webLlmNav", action: map[id] }));
  });
  const setup = document.getElementById("web-embed-setup");
  if (setup) {
    setup.addEventListener("toggle", () => {
      setup.setAttribute("data-user-toggled", "1");
      if (isWebEmbedActive()) scheduleWebEmbedContentRect();
    });
  }
  const labelToggle = document.getElementById("web-bookmark-label-toggle");
  if (labelToggle) {
    labelToggle.addEventListener("click", () => {
      state.webBookmarkShowLabels = !state.webBookmarkShowLabels;
      saveWebBookmarkLabelsPref(state.webBookmarkShowLabels);
      syncWebBookmarkLabelsUi();
      scheduleWebEmbedContentRect();
    });
  }
  if (state.webBookmarkShowLabels == null) state.webBookmarkShowLabels = loadWebBookmarkLabelsPref();
  syncWebBookmarkLabelsUi();
  syncWebEmbedLayout();
  renderWebEmbedTabBar();
  initWebEmbedDebugPanel();
}

function initWebEmbedColumnResizeHandles() {
  /* 列宽拖动由宿主 AHK 拖条处理 */
}

let _scWebEmbedScrollDebounce = 0;
let _scWebEmbedScrollSyncTimer = 0;

function syncWebEmbedScrollToHost() {
  if (!isWebEmbedActive() || _scWebEmbedLayoutFromHost) return;
  const viewport = document.getElementById("web-embed-scroll-viewport");
  if (!viewport) return;
  syncWebEmbedViewportScroll(false);
  const vpW = getWebEmbedViewportWidthPx();
  const stripW = getWebEmbedStripWidth(getWebEmbedLayoutSites());
  const maxScroll = Math.max(0, stripW - vpW);
  const scrollX = Math.min(Math.max(0, Math.round(viewport.scrollLeft || 0)), maxScroll);
  postToAhk({
    type: "webLlmScroll",
    scrollX,
    viewportWidth: vpW,
    stripWidth: stripW
  });
}

function initWebEmbedColumnLayout() {
  initWebEmbedHScroll();
  const viewport = document.getElementById("web-embed-scroll-viewport");
  if (!viewport || viewport.getAttribute("data-layout-ready") === "1") return;
  viewport.setAttribute("data-layout-ready", "1");
  viewport.addEventListener("scroll", () => {
    if (_scWebEmbedLayoutFromHost) return;
    syncWebEmbedHScrollUi();
    if (_scWebEmbedHScrollDragging) return;
    if (_scWebEmbedScrollSyncTimer) clearTimeout(_scWebEmbedScrollSyncTimer);
    _scWebEmbedScrollSyncTimer = setTimeout(() => {
      _scWebEmbedScrollSyncTimer = 0;
      syncWebEmbedScrollToHost();
    }, 36);
    if (isWebEmbedActive() && _scWebEmbedFocusState.siteId) {
      animateWebEmbedFocusFrame(_scWebEmbedFocusState.siteId, true);
    }
  }, { passive: true });
  viewport.addEventListener("pointerup", () => {
    if (_scWebEmbedLayoutFromHost) return;
    syncWebEmbedScrollToHost();
  }, { passive: true });
  renderWebEmbedColumnTrack();
  if (typeof ResizeObserver === "function") {
    const track = document.getElementById("web-embed-scroll-track");
    if (track && !viewport._scWebEmbedResizeObs) {
      viewport._scWebEmbedResizeObs = new ResizeObserver(() => {
        if (isWebEmbedActive() && _scWebEmbedFocusState.siteId) {
          animateWebEmbedFocusFrame(_scWebEmbedFocusState.siteId, true);
        }
      });
      viewport._scWebEmbedResizeObs.observe(track);
    }
  }
}
function openWebEmbedSetupFromNav() {
  if (getUIMode() !== "web") setUIMode("web", true);
  const catFolder = document.getElementById("sc-web-nav-cat-folder");
  const addFolder = document.getElementById("sc-web-nav-add-folder");
  const morePanel = document.getElementById("sc-web-nav-more-panel");
  if (catFolder) catFolder.open = true;
  if (addFolder) {
    addFolder.open = true;
    addFolder.scrollIntoView({ behavior: "smooth", block: "nearest" });
  }
  if (morePanel) {
    morePanel.open = true;
    morePanel.classList.remove("hidden");
    morePanel.scrollIntoView({ behavior: "smooth", block: "nearest" });
  }
}

function ensureWebModeNavBodyShell(body) {
  if (!body) return;
  if (body.querySelector(".sc-web-nav-root") && body.querySelector("#sc-web-nav-tabs-block")) return;
  body.innerHTML = "";
  body.innerHTML =
    "<div class=\"sc-web-nav-root\">" +
      "<details class=\"sc-web-nav-cat-folder\" id=\"sc-web-nav-cat-folder\">" +
        "<summary class=\"sc-web-nav-cat-folder-sum\">联网分类</summary>" +
        "<div class=\"sc-web-nav-cat-folder-body\">" +
          "<div id=\"web-nav-categories\" class=\"sc-web-nav-categories\" aria-label=\"联网分类\"></div>" +
        "</div>" +
      "</details>" +
      "<div class=\"sc-web-nav-tabs-block\" id=\"sc-web-nav-tabs-block\">" +
        "<div class=\"sc-web-nav-tabs-head\">" +
          "<span class=\"sc-web-nav-tabs-title\">AI 页面</span>" +
          "<span id=\"sc-web-ai-count\" class=\"sc-web-ai-count\">0/8</span>" +
        "</div>" +
        "<div class=\"sc-web-nav-tabs-scroll\" id=\"sc-web-nav-tabs-scroll\">" +
          "<div class=\"sc-web-nav-tabs-inner web-embed-tabbar-inner\">" +
            "<div id=\"web-embed-tab-indicator\" class=\"web-embed-tab-indicator sc-web-nav-tab-indicator\" aria-hidden=\"true\"></div>" +
            "<div id=\"webllm-site-chips\" class=\"sc-web-nav-tabs web-embed-tabs\" role=\"tablist\" aria-label=\"AI 站点标签\"></div>" +
          "</div>" +
        "</div>" +
      "</div>" +
      "<details class=\"sc-web-nav-add-folder\" id=\"sc-web-nav-add-folder\">" +
        "<summary class=\"sc-web-nav-add-folder-sum\">+ 添加 AI</summary>" +
        "<div id=\"sc-web-nav-ai-list\" class=\"sc-web-nav-ai-list\" role=\"list\"></div>" +
      "</details>" +
      "<details class=\"sc-web-nav-more-panel hidden\" id=\"sc-web-nav-more-panel\">" +
        "<summary class=\"sc-web-nav-more-panel-sum\">搜索引擎</summary>" +
        "<div class=\"sc-web-nav-more-panel-body\">" +
          "<div id=\"web-nav-engines\" class=\"sc-web-nav-engines\" aria-label=\"搜索引擎\"></div>" +
        "</div>" +
      "</details>" +
      "<button type=\"button\" class=\"sc-web-nav-more-btn\" id=\"sc-web-nav-more-btn\">" +
        "<span class=\"sc-web-nav-more-icon\">+</span>" +
        "<span class=\"sc-web-nav-more-text\">更多 AI…</span>" +
        "<span class=\"sc-web-nav-more-hint\">分类与引擎</span>" +
      "</button>" +
    "</div>";
  const moreBtn = body.querySelector("#sc-web-nav-more-btn");
  if (moreBtn) moreBtn.addEventListener("click", openWebEmbedSetupFromNav);
  ensureWebEmbedTabScrollSync();
}

function updateWebEmbedAiCount() {
  const el = document.getElementById("sc-web-ai-count");
  if (!el) return;
  const n = getWebEmbedBroadcastSites().length;
  el.textContent = n + "/" + SC_WEB_EMBED_MAX_COLUMNS;
}

function appendWebEmbedPoolSection(listEl, label) {
  const lab = document.createElement("div");
  lab.className = "sc-web-ai-section-label";
  lab.textContent = label;
  listEl.appendChild(lab);
  const pool = document.createElement("div");
  pool.className = "sc-web-ai-pool";
  listEl.appendChild(pool);
  return pool;
}

function createWebEmbedPoolChip(site, isOn, isFocus) {
  const btn = document.createElement("button");
  btn.type = "button";
  btn.className = "sc-web-ai-pool-chip" + (isOn ? " is-on" : "") + (isFocus ? " is-focus" : "") + (site.embedRisk && site.embedRisk !== "none" ? " is-risk" : "");
  btn.setAttribute("data-site", site.id);
  btn.setAttribute("role", "listitem");
  mountWebChipIcon(btn, site);
  const label = document.createElement("span");
  label.className = "sc-web-ai-pool-chip__label";
  label.textContent = site.label;
  btn.appendChild(label);
  const act = document.createElement("span");
  act.className = "sc-web-ai-pool-chip__act";
  act.textContent = isOn ? "✓" : "+";
  act.setAttribute("aria-hidden", "true");
  btn.appendChild(act);
  const riskHint = site.embedRisk === "login" ? " · 可能需登录" : (site.embedRisk === "untested" ? " · 实验性" : "");
  btn.title = site.label + (isOn ? " · 已参与同问" : " · 点击添加") + riskHint;
  btn.addEventListener("click", (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (!isWebEmbedSiteEnabled(site)) return;
    const addFolder = document.getElementById("sc-web-nav-add-folder");
    if (e.ctrlKey || e.metaKey) {
      toggleWebEmbedBroadcastSite(site.id);
      return;
    }
    const broadcast = getWebEmbedBroadcastSites();
    if (broadcast.includes(site.id)) {
      if (getUIMode() !== "web") setUIMode("web", true);
      if (!isWebEmbedCategory()) selectCategoryLocal("ai", true);
      setWebEmbedFocusSite(site.id, true);
      return;
    }
    toggleWebEmbedBroadcastSite(site.id);
    if (addFolder) addFolder.open = false;
  });
  return btn;
}

function renderWebModeNavBody() {
  const card = document.querySelector('.sc-mode-card[data-mode="web"]');
  if (card) {
    const body = card.querySelector(".sc-mode-card-body");
    if (body) ensureWebModeNavBodyShell(body);
  }
  const list = document.getElementById("sc-web-nav-ai-list");
  if (!list) return;
  const broadcast = getWebEmbedBroadcastSites();
  const pool = getWebEmbedPoolSites();
  list.innerHTML = "";
  updateWebEmbedAiCount();

  const addable = pool.filter((s) => !broadcast.includes(s.id));
  const stableAdd = addable.filter((s) => s.embedRisk === "none" || !s.embedRisk);
  const riskyAdd = addable.filter((s) => s.embedRisk && s.embedRisk !== "none");

  if (stableAdd.length) {
    const addPool = appendWebEmbedPoolSection(list, "可添加");
    stableAdd.forEach((site) => addPool.appendChild(createWebEmbedPoolChip(site, false, false)));
  }
  if (riskyAdd.length) {
    const riskPool = appendWebEmbedPoolSection(list, "实验性 / 需登录");
    riskyAdd.forEach((site) => riskPool.appendChild(createWebEmbedPoolChip(site, false, false)));
  }
  if (!addable.length) {
    const empty = document.createElement("p");
    empty.className = "sc-web-nav-placeholder";
    empty.textContent = "已添加全部可用 AI";
    list.appendChild(empty);
  }

  const addFolder = document.getElementById("sc-web-nav-add-folder");
  if (addFolder && addable.length > 0) addFolder.classList.remove("hidden");
  else if (addFolder && broadcast.length < SC_WEB_EMBED_MAX_COLUMNS) addFolder.classList.remove("hidden");

  renderCategories();
  renderWebEmbedTabBar();
  syncWebModeNavAiRows();
}

function syncWebModeNavAiRows() {
  const focus = getWebEmbedActiveEngine();
  const broadcast = new Set(getWebEmbedBroadcastSites());
  updateWebEmbedAiCount();
  document.querySelectorAll(".sc-web-ai-pool-chip").forEach((chip) => {
    const sid = String(chip.getAttribute("data-site") || "");
    const on = broadcast.has(sid);
    chip.classList.toggle("is-on", on);
    chip.classList.toggle("is-focus", sid === focus);
    const act = chip.querySelector(".sc-web-ai-pool-chip__act");
    if (act) act.textContent = on ? "✓" : "+";
  });
  const chromeMap = (state.webEmbedSiteChrome && typeof state.webEmbedSiteChrome === "object")
    ? state.webEmbedSiteChrome
    : {};
  document.querySelectorAll(".sc-web-ai-row").forEach((row) => {
    const sid = String(row.getAttribute("data-site") || "");
    const chrome = chromeMap[sid] || {};
    const isFocus = sid === focus;
    const loading = isFocus && !!chrome.loading;
    row.classList.toggle("is-active", isFocus);
    row.classList.toggle("is-loading", loading);
    row.classList.toggle("broadcast-on", broadcast.has(sid));
    row.classList.toggle("broadcast-off", !broadcast.has(sid));
    const site = SC_WEB_EMBED_SITES.find((s) => s.id === sid);
    const label = site ? site.label : sid;
    row.title = label + (broadcast.has(sid) ? " · 已参与同问" : " · 未参与同问") + "（点击切换，Ctrl+点击增删同问）";
    const sub = row.querySelector(".sc-web-ai-row__sub");
    if (sub) {
      if (loading) sub.textContent = "当前任务：加载中 60%";
      else if (isFocus && (chrome.title || chrome.url)) {
        const t = String(chrome.title || chrome.url || "");
        sub.textContent = "当前任务：" + (t.length > 20 ? t.slice(0, 20) + "…" : t);
      } else sub.textContent = "当前任务：待命";
    }
    const fill = row.querySelector(".sc-web-ai-row__progress-fill");
    if (fill) {
      fill.classList.toggle("is-indeterminate", loading);
      if (loading) fill.style.width = "60%";
      else if (isFocus) fill.style.width = "100%";
      else fill.style.width = "0%";
    }
    const dot = row.querySelector(".sc-web-ai-row__dot");
    if (dot) {
      dot.classList.remove("dot-active", "dot-loading", "dot-ready");
      if (loading) dot.classList.add("dot-loading");
      else if (isFocus) dot.classList.add("dot-active");
      else dot.classList.add("dot-ready");
    }
  });
}


function scWebEmbedPrepareWebMode() {
  _scWebEmbedLastRectKey = "";
  _scWebEmbedLastLayoutKey = "";
  _scWebEmbedHostBootstrapped = false;
  const viewport = document.getElementById("web-embed-scroll-viewport");
  if (viewport) viewport.scrollLeft = 0;
}

function scWebEmbedInvalidateContentRect() {
  _scWebEmbedLastRectKey = "";
}

function isWebEmbedDebugPanelOpen() {
  return !!(_scWebEmbedDebugState && _scWebEmbedDebugState.open);
}

if (typeof globalThis !== "undefined") {
  globalThis.ScWebEmbed = globalThis.ScWebEmbed || { loaded: true };
  globalThis.ScWebEmbed.loaded = true;
}
