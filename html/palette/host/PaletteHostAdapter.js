/**
 * PaletteHostAdapter — Command Palette WebView ↔ AHK 消息出入口
 *
 * Cat-A Patch 2：集中 postMessage 出站与 host 入站分发；不改变消息协议与 payload 字段。
 */
(function (root) {
  var handlers = [];
  var listenerInstalled = false;

  function getWebView() {
    try {
      if (root.chrome && root.chrome.webview) return root.chrome.webview;
    } catch (_) {}
    return null;
  }

  function normalizeHostMessage(raw) {
    var d = raw;
    if (raw && typeof raw === "object" && raw.data !== undefined && !raw.type) {
      d = raw.data;
    }
    if (typeof d === "string") {
      try {
        d = JSON.parse(d);
      } catch (_) {
        return null;
      }
    }
    if (!d || !d.type) return null;
    return d;
  }

  function dispatchToHandlers(message, ev) {
    for (var i = 0; i < handlers.length; i++) {
      try {
        handlers[i](message, ev);
      } catch (_) {}
    }
  }

  function installListener() {
    if (listenerInstalled) return;
    var wv = getWebView();
    if (!wv || typeof wv.addEventListener !== "function") return;
    listenerInstalled = true;
    wv.addEventListener("message", function (ev) {
      var d = normalizeHostMessage(ev);
      if (!d) return;
      dispatchToHandlers(d, ev);
    });
  }

  function send(type, payload, meta) {
    meta = meta || {};
    payload = payload || {};
    var o = Object.assign({}, payload);
    if (type) o.type = String(type);
    var typ = o.type ? String(o.type) : "";
    if (!typ) return { ok: false, reason: "missing_type" };

    if (!meta.direct) {
      if (typ === "palette_search_debug" && !o.tab) {
        try {
          if (root.ahk && typeof root.ahk.OpenCommandPaletteSearchDebug === "function") {
            if (String(root.ahk.OpenCommandPaletteSearchDebug()) === "ok") {
              return { ok: true, via: "ahk" };
            }
          }
        } catch (_) {}
      }
      if (typ === "palette_agent_debug") {
        o = { type: "palette_search_debug", tab: "agent" };
        typ = o.type;
      }
      if (typ === "palette_agent_submit") {
        if (o._hostSynced) return { ok: true, skipped: true, via: "host_synced" };
        if (meta.debugLog) {
          try {
            meta.debugLog("submit_postmsg_only", "fallback", "warn");
          } catch (_) {}
        }
      }
    }

    var payloadStr = "";
    try {
      payloadStr = JSON.stringify(o);
    } catch (_) {
      return { ok: false, reason: "stringify_failed" };
    }

    var wv = getWebView();
    try {
      if (wv && typeof wv.postMessage === "function") {
        wv.postMessage(payloadStr);
        return { ok: true, via: "postMessage" };
      }
    } catch (_) {}
    try {
      if (wv) {
        wv.postMessage(o);
        return { ok: true, via: "postMessage_object" };
      }
    } catch (_2) {}
    return { ok: false, reason: "webview_unavailable" };
  }

  function onMessage(handler) {
    if (typeof handler !== "function") return;
    handlers.push(handler);
    installListener();
  }

  function emitLocalMockMessage(message) {
    var d = normalizeHostMessage(message);
    if (!d) return false;
    dispatchToHandlers(d, { data: d, mock: true });
    return true;
  }

  root.PaletteHostAdapter = {
    send: send,
    onMessage: onMessage,
    normalizeHostMessage: normalizeHostMessage,
    emitLocalMockMessage: emitLocalMockMessage
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
