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
  const framePool = new Map();

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

  function postToAhk(obj) {
    if (!window.chrome?.webview) return;
    const p = Object.assign({ v: 1, timestamp: Date.now() }, obj || {});
    if (p.action === undefined && p.type !== undefined) p.action = p.type;
    window.chrome.webview.postMessage(p);
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
    entry.inited = true;
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
      entry.ready = true;
      flushPendingHostMsgs(entry);
      flushReadyQueue(entry);
    });

    if (opts.loadNow !== false) iframe.src = file;
    frameWrap().appendChild(iframe);
    return entry;
  }

  function hydrateAndShow(entry, tab, opts) {
    opts = opts || {};
    const navigate = !!opts.navigate;
    const doShow = () => {
      activateEntry(entry);
      if (!entry.inited && pendingInit) {
        pushInitToFrame(entry, navigate);
      } else if (pendingInit && initDataSeen) {
        postToFrame(entry, {
          channel: "nmer-settings-host",
          type: "hostForward",
          message: { type: "initData", payload: pendingInit, navigateToStartTab: false }
        });
      }
      postSetActiveTab(entry, tab);
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
    const samePane = tabFile(prevTab) === file && activeFrame?.file === file;

    if (samePane && entry.ready && entry.inited) {
      activateEntry(entry);
      postSetActiveTab(entry, tab);
      return;
    }

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
      || t === "syncNiumaChatLlmResult";
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
        btn.addEventListener("mouseenter", () => prefetchFile(tabFile(tab)), { passive: true });
        btn.addEventListener("click", () => {
          const next = normalizeStartTab(btn.dataset.tab);
          if (next === activeTab) return;
          loadTab(next, { navigate: false });
        });
      });

      if (window.chrome?.webview) {
        window.chrome.webview.addEventListener("message", e => {
          const data = typeof e.data === "string" ? JSON.parse(e.data) : e.data;
          if (!data?.type) return;
          if (data.type === "initData") {
            pendingInit = data.payload || {};
            initDataSeen = true;
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
            prefetchOthers(400);
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
        postToAhk({ type: "ready" });
      } else {
        loadTab("general", { navigate: false });
      }
    }
  };

  window.addEventListener("message", e => {
    const d = e.data;
    if (!d) return;
    if (d.channel === "nmer-settings-child" && d.payload) {
      relayChildToAhk(d.payload, e.source || null);
      return;
    }
    if (d.channel !== "nmer-settings-child-action") return;
    postToAhk(Object.assign({ type: d.type }, d.payload || {}));
  });
})();
