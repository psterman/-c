(function () {
  const TAB_PAGES = {
    general: "settings/SettingsGeneral.html",
    appearance: "settings/SettingsGeneral.html",
    prompts: "settings/SettingsPrompts.html",
    hotkeys: "settings/SettingsHotkeys.html",
    advanced: "settings/SettingsSystem.html",
    storage: "settings/SettingsSystem.html",
    screenshot: "settings/SettingsSystem.html",
    search: "settings/SettingsWorkspace.html",
    customize: "settings/SettingsWorkspace.html"
  };
  const ALL_FILES = [...new Set(Object.values(TAB_PAGES))];

  let activeTab = "general";
  let activeFrame = null;
  let pendingInit = null;
  let initDataSeen = false;
  let initDataTick = 0;
  const framePool = new Map();
  const AUTO_PREFETCH_OTHER_TABS = true;
  const PREFETCH_COOLDOWN_MS = 2600;

  function normalizeStartTab(tab) {
    const t = String(tab || "general").trim();
    return TAB_PAGES[t] ? t : "general";
  }

  function tabFile(tab) {
    return TAB_PAGES[tab] || TAB_PAGES.general;
  }

  function frameWrap() {
    return document.getElementById("frame-wrap");
  }

  function setFrameLoading(show) {
    const el = document.getElementById("frame-loading");
    if (el) el.style.display = show ? "flex" : "none";
  }

  function postToAhk(obj) {
    if (!window.chrome?.webview) return;
    const p = Object.assign({ v: 1, timestamp: Date.now() }, obj || {});
    if (p.action === undefined && p.type !== undefined) p.action = p.type;
    window.chrome.webview.postMessage(p);
  }

  function trace(event, detail, extra) {
    const payload = {
      type: "settingsTrace",
      source: "bridge",
      event: String(event || ""),
      detail: String(detail || ""),
      activeTab: String(activeTab || ""),
      file: activeFrame?.file || ""
    };
    if (extra && typeof extra === "object")
      Object.assign(payload, extra);
    try { postToAhk(payload); } catch (_) {}
  }

  function postToFrame(entry, msg) {
    if (!entry?.iframe?.contentWindow) return;
    entry.iframe.contentWindow.postMessage(msg, "*");
  }

  function postToFrameQueued(entry, msg) {
    if (!entry) return;
    if (entry.ready && entry.iframe?.contentWindow) {
      postToFrame(entry, msg);
      return;
    }
    if (!entry.pendingHostMsgs) entry.pendingHostMsgs = [];
    entry.pendingHostMsgs.push(msg);
  }

  function flushPendingHostMsgs(entry) {
    const q = entry.pendingHostMsgs || [];
    entry.pendingHostMsgs = [];
    q.forEach((m) => { try { postToFrame(entry, m); } catch (_) {} });
  }

  function pushInitToFrame(entry, navigate) {
    if (!pendingInit || !entry?.iframe?.contentWindow) return;
    postToFrame(entry, {
      channel: "nmer-settings-host",
      type: "initSlice",
      payload: pendingInit,
      navigateToStartTab: !!navigate
    });
  }

  function postSetActiveTab(entry, tab) {
    postToFrame(entry, { channel: "nmer-settings-host", type: "setActiveTab", tab: tab });
  }

  function setShellActiveTab(tab) {
    document.querySelectorAll("#sidebar .tab-btn").forEach(b => {
      b.classList.toggle("active", b.dataset.tab === tab);
    });
  }

  function activateEntry(entry) {
    framePool.forEach(e => e.iframe.classList.toggle("is-active", e === entry));
    activeFrame = entry;
    // WebView2 某些机器上 iframe 首帧可能要一次用户交互才绘制，主动焦点+重排可避免白屏卡住。
    try { entry?.iframe?.focus(); } catch (_) {}
    try { entry?.iframe?.contentWindow?.focus(); } catch (_) {}
    try { window.dispatchEvent(new Event("resize")); } catch (_) {}
  }

  function runWhenReady(entry, fn) {
    if (entry.ready) {
      fn();
      return;
    }
    if (!entry.readyQueue) entry.readyQueue = [];
    entry.readyQueue.push(fn);
  }

  function flushReadyQueue(entry) {
    const q = entry.readyQueue || [];
    entry.readyQueue = [];
    q.forEach(fn => { try { fn(); } catch (_) {} });
  }

  function findEntryByWindow(win) {
    if (!win) return null;
    for (const entry of framePool.values()) {
      try {
        if (entry.iframe?.contentWindow === win) return entry;
      } catch (_) {}
    }
    return null;
  }

  function markEntryReady(entry, reason) {
    if (!entry || entry.ready) return;
    entry.ready = true;
    entry.readyReason = String(reason || "ready");
    trace("entry_ready", entry.file, { reason: entry.readyReason });
    flushPendingHostMsgs(entry);
    flushReadyQueue(entry);
    if (entry === activeFrame) setFrameLoading(false);
  }

  function ensureFrame(file, opts) {
    opts = opts || {};
    if (framePool.has(file)) return framePool.get(file);

    const iframe = document.createElement("iframe");
    iframe.className = "settings-frame-pane";
    iframe.title = "设置内容";
    if (opts.prefetch) iframe.setAttribute("loading", "lazy");

    const entry = {
      file,
      iframe,
      ready: false,
      inited: false,
      readyQueue: []
    };
    framePool.set(file, entry);

    iframe.addEventListener("load", () => {
      markEntryReady(entry, "iframe_load");
    });

    if (opts.loadNow !== false) iframe.src = file;
    frameWrap().appendChild(iframe);
    return entry;
  }

  function hydrateAndShow(entry, tab, opts) {
    opts = opts || {};
    const navigate = !!opts.navigate;
    trace("hydrate_show_begin", entry.file, { tab, navigate: !!navigate, inited: !!entry.inited, ready: !!entry.ready });
    activateEntry(entry);
    // 首屏先给骨架，避免卡在“完整 load 才可见”
    setFrameLoading(true);
    setTimeout(() => {
      if (activeFrame === entry && !entry.ready)
        setFrameLoading(false);
    }, 380);
    const doShow = () => {
      trace("hydrate_show_ready", entry.file, { tab, navigate: !!navigate, inited: !!entry.inited, ready: !!entry.ready });
      if (!entry.inited && pendingInit) {
        trace("push_init_slice", entry.file, { tab, navigate: !!navigate });
        pushInitToFrame(entry, navigate);
      } else if (pendingInit && initDataSeen) {
        trace("push_init_forward", entry.file, { tab });
        postToFrame(entry, {
          channel: "nmer-settings-host",
          type: "hostForward",
          message: { type: "initData", payload: pendingInit, navigateToStartTab: false }
        });
      }
      postSetActiveTab(entry, tab);
      setFrameLoading(false);
      try { entry?.iframe?.focus(); } catch (_) {}
      try { entry?.iframe?.contentWindow?.focus(); } catch (_) {}
    };
    runWhenReady(entry, doShow);
  }

  function loadTab(tab, opts) {
    opts = opts || {};
    const prevTab = activeTab;
    const file = tabFile(tab);
    activeTab = tab;
    setShellActiveTab(tab);
    try { sessionStorage.setItem("settings.activeTab", tab); } catch (_) {}

    const entry = ensureFrame(file);
    trace("load_tab", file, { tab, prevTab, sameFile: tabFile(prevTab) === file });
    const samePane = tabFile(prevTab) === file && activeFrame?.file === file;

    if (samePane && entry.ready && entry.inited) {
      activateEntry(entry);
      postSetActiveTab(entry, tab);
      setFrameLoading(false);
      return;
    }

    setFrameLoading(true);
    hydrateAndShow(entry, tab, opts);
  }

  function prefetchFile(file) {
    if (framePool.has(file)) return;
    ensureFrame(file, { loadNow: true, prefetch: true });
  }

  function prefetchOthers(delayMs) {
    const activeFile = tabFile(activeTab);
    const rest = ALL_FILES.filter(f => f !== activeFile);
    let i = 0;
    function step() {
      if (i >= rest.length) return;
      prefetchFile(rest[i++]);
      setTimeout(step, delayMs);
    }
    const start = () => setTimeout(step, delayMs);
    if (typeof requestIdleCallback === "function") requestIdleCallback(start, { timeout: 2500 });
    else start();
  }

  function shouldBroadcastToAllFrames(msg) {
    const t = String(msg?.type || "");
    return t === "testUserStudioLlmResult"
      || t === "testUserStudioLlmAck"
      || t === "saveUserStudioResult"
      || t === "browseUserStudioPathResult"
      || t === "hermes_studio_status"
      || t === "openclaw_studio_status"
      || t === "hermes_host_token_probe"
      || t === "openclaw_host_token_probe"
      || t === "syncNiumaChatLlmResult"
      || t === "summonProbeReport"
      || t === "summonProbeResult"
      || t === "summonProbeWait"
      || t === "summonProbeInteractiveStarted"
      || t === "applySummonSafeModeResult"
      || t === "saveResult"
      || t === "vkStatus"
      || t === "vkWebEvent"
      || t === "keybinderCatalogSnapshot"
      || t === "keybinderBindingsSnapshot";
  }

  let lastStudioTestSource = null;

  function postHostToChild(sourceWindow, data) {
    const wrapper = { channel: "nmer-settings-host", type: "hostForward", message: data };
    if (sourceWindow && typeof sourceWindow.postMessage === "function") {
      try { sourceWindow.postMessage(wrapper, "*"); } catch (_) {}
    }
  }

  function deliverLlmTestResult(data) {
    if (!data || data.type !== "testUserStudioLlmResult") {
      forwardHostMessage(data);
      return;
    }
    forwardHostMessage(data);
    const src = lastStudioTestSource;
    if (!src) return;
    const fire = () => {
      try { postHostToChild(src, data); } catch (_) {}
    };
    fire();
    setTimeout(fire, 40);
    setTimeout(fire, 120);
    setTimeout(fire, 300);
  }

  function forwardHostMessage(data) {
    const wrapper = { channel: "nmer-settings-host", type: "hostForward", message: data };
    if (data?.type === "testUserStudioLlmResult" && lastStudioTestSource) {
      postHostToChild(lastStudioTestSource, data);
    }
    if (shouldBroadcastToAllFrames(data)) {
      framePool.forEach((entry) => postToFrameQueued(entry, wrapper));
      return;
    }
    if (activeFrame?.iframe?.contentWindow) {
      postToFrameQueued(activeFrame, wrapper);
    }
  }

  function relayChildToAhk(payload, sourceWindow) {
    if (!payload || typeof payload !== "object") return false;
    if (payload.type === "testUserStudioLlm") {
      lastStudioTestSource = sourceWindow || (activeFrame?.iframe?.contentWindow || null);
      const tid = String(payload.testId || "").trim();
      const ack = { type: "testUserStudioLlmAck", testId: tid, via: "bridge" };
      postHostToChild(lastStudioTestSource, ack);
      forwardHostMessage(ack);
    }
    postToAhk(payload);
    return true;
  }

  window.NmerSettingsBridge = {
    postToAhk,
    relayChildToAhk,
    forwardHostMessage,
    init: function () {
      document.querySelectorAll("#sidebar .tab-btn").forEach(btn => {
        const tab = normalizeStartTab(btn.dataset.tab);
        btn.addEventListener("mouseenter", () => {
          if (!initDataTick || (Date.now() - initDataTick) < PREFETCH_COOLDOWN_MS) return;
          prefetchFile(tabFile(tab));
        }, { passive: true });
        btn.addEventListener("click", () => {
          const next = normalizeStartTab(btn.dataset.tab);
          if (next === activeTab) return;
          trace("sidebar_click", tabFile(next), { tab: next });
          loadTab(next, { navigate: false });
        });
      });

      if (window.chrome?.webview) {
        window.chrome.webview.addEventListener("message", e => {
          const data = typeof e.data === "string" ? JSON.parse(e.data) : e.data;
          if (!data?.type) return;
          if (data.type === "initData") {
            trace("host_initdata", "", { navigateToStartTab: !!data.navigateToStartTab });
            pendingInit = data.payload || {};
            initDataSeen = true;
            initDataTick = Date.now();
            let tab = "general";
            if (data.navigateToStartTab) {
              tab = normalizeStartTab(pendingInit.defaultStartTab);
            } else {
              try {
                const last = sessionStorage.getItem("settings.activeTab");
                if (last) tab = normalizeStartTab(last);
              } catch (_) {}
            }
            loadTab(tab, { navigate: !!data.navigateToStartTab });
            if (AUTO_PREFETCH_OTHER_TABS) prefetchOthers(400);
            return;
          }
          if (data.type === "testUserStudioLlmResult") {
            deliverLlmTestResult(data);
            return;
          }
          if (shouldBroadcastToAllFrames(data) || activeFrame?.iframe?.contentWindow) {
            forwardHostMessage(data);
          }
        });
        // 先加载通用页骨架，避免首次进入右侧空白直到收到 initData。
        loadTab("general", { navigate: false });
        postToAhk({ type: "ready" });
        // 兜底：首个 ready 若被宿主吞掉，补发一次避免“必须点一下才加载”。
        setTimeout(() => { try { postToAhk({ type: "ready" }); } catch (_) {} }, 120);
      } else {
        loadTab("general", { navigate: false });
      }
    }
  };

  window.addEventListener("message", e => {
    const d = e.data;
    if (!d) return;
    if (d.channel === "nmer-settings-child-lifecycle") {
      const entry = findEntryByWindow(e.source || null);
      if (entry) {
        const stage = String(d.stage || "lifecycle");
        trace("child_lifecycle", entry.file, { stage });
        if (stage === "bridge_ready" || stage === "dom_ready" || stage === "app_ready")
          markEntryReady(entry, stage);
        if (stage === "init_applied")
          entry.inited = true;
        if (stage === "request_init") {
          trace("child_request_init", entry.file, { inited: !!entry.inited, hasPendingInit: !!pendingInit });
          if (pendingInit) {
            pushInitToFrame(entry, false);
            postSetActiveTab(entry, activeTab);
          }
        }
      }
      return;
    }
    if (d.channel === "nmer-settings-child" && d.payload) {
      relayChildToAhk(d.payload, e.source || null);
      return;
    }
    if (d.channel !== "nmer-settings-child-action") return;
    postToAhk(Object.assign({ type: d.type }, d.payload || {}));
  });
})();
