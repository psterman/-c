(function () {
  window.postToParent = function (type, payload) {
    window.parent.postMessage({ channel: "nmer-settings-child-action", type: type, payload: payload || {} }, "*");
  };

  if (window.parent === window) return;

  const hostListeners = [];
  const pendingHostEvents = [];

  function notifyHostListeners(data) {
    if (!data) return;
    const evt = { data };
    if (!hostListeners.length) {
      pendingHostEvents.push(evt);
      return;
    }
    hostListeners.forEach((fn) => {
      try { fn(evt); } catch (_) {}
    });
  }

  function flushPendingHostEvents() {
    if (!pendingHostEvents.length || !hostListeners.length) return;
    const q = pendingHostEvents.splice(0, pendingHostEvents.length);
    q.forEach((evt) => {
      hostListeners.forEach((fn) => {
        try { fn(evt); } catch (_) {}
      });
    });
  }

  function onHostEnvelope(d) {
    if (!d || d.channel !== "nmer-settings-host") return;
    if (d.type === "hostForward") notifyHostListeners(d.message || d);
    else if (d.type === "initSlice") {
      notifyHostListeners({ type: "initData", payload: d.payload || {}, navigateToStartTab: !!d.navigateToStartTab });
    } else if (d.type === "setActiveTab" && d.tab) {
      notifyHostListeners({ type: "setActiveTab", tab: d.tab });
    }
  }

  window.addEventListener("message", (e) => {
    try { onHostEnvelope(e.data); } catch (_) {}
  });

  function relayToParentShell(payload) {
    try {
      const bridge = window.parent && window.parent.NmerSettingsBridge;
      if (bridge && typeof bridge.relayChildToAhk === "function") {
        bridge.relayChildToAhk(payload, window);
        return true;
      }
      if (bridge && typeof bridge.postToAhk === "function") {
        bridge.postToAhk(payload);
        return true;
      }
    } catch (_) {}
    try {
      window.parent.postMessage({ channel: "nmer-settings-child", payload }, "*");
      return true;
    } catch (_) {}
    return false;
  }

  if (!window.chrome) window.chrome = {};
  const native = window.chrome.webview;
  const nativePost = native && typeof native.postMessage === "function"
    ? native.postMessage.bind(native)
    : null;
  const nativeAdd = native && typeof native.addEventListener === "function"
    ? native.addEventListener.bind(native)
    : null;
  const nativeRemove = native && typeof native.removeEventListener === "function"
    ? native.removeEventListener.bind(native)
    : null;

  window.chrome.webview = {
    postMessage(obj) {
      const payload = Object.assign({ v: 1, timestamp: Date.now() }, obj || {});
      if (payload.action === undefined && payload.type !== undefined) payload.action = payload.type;
      if (relayToParentShell(payload)) return;
      if (nativePost) nativePost(payload);
    },
    addEventListener(type, fn) {
      if (type === "message" && typeof fn === "function") {
        hostListeners.push(fn);
        flushPendingHostEvents();
        return;
      }
      if (nativeAdd) nativeAdd(type, fn);
    },
    removeEventListener(type, fn) {
      if (type === "message") {
        const i = hostListeners.indexOf(fn);
        if (i >= 0) hostListeners.splice(i, 1);
        return;
      }
      if (nativeRemove) nativeRemove(type, fn);
    }
  };

  function notifyLifecycle(stage) {
    try {
      window.parent.postMessage({ channel: "nmer-settings-child-lifecycle", stage: String(stage || "") }, "*");
    } catch (_) {}
  }

  notifyLifecycle("bridge_ready");
  document.addEventListener("DOMContentLoaded", () => notifyLifecycle("dom_ready"), { once: true });
})();
