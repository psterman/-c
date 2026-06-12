(function (global) {
  "use strict";

  var sessionId = "cp_" + Date.now().toString(36) + "_" + Math.random().toString(36).slice(2, 7);
  var marks = Object.create(null);
  var pendingPosts = [];
  var flushTimer = 0;
  var firstInputDone = false;
  var senderFn = null;

  function nowMs() {
    if (typeof performance !== "undefined" && typeof performance.now === "function") {
      return performance.now();
    }
    return Date.now();
  }

  function queuePost(event, extra) {
    pendingPosts.push({
      type: "palette_perf_event",
      ts: Date.now(),
      sessionId: sessionId,
      source: extra && extra.source ? String(extra.source) : "web",
      event: String(event || ""),
      durationMs: extra && extra.durationMs != null ? Number(extra.durationMs) : 0,
      generation: extra && extra.generation != null ? Number(extra.generation) : 0,
      resultCount: extra && extra.resultCount != null ? Number(extra.resultCount) : 0,
      layoutMode: extra && extra.layoutMode ? String(extra.layoutMode) : "",
      emptyResult: !!(extra && extra.emptyResult)
    });
    if (flushTimer) return;
    flushTimer = setTimeout(flushPosts, 32);
  }

  function flushPosts() {
    flushTimer = 0;
    if (!pendingPosts.length) return;
    var batch = pendingPosts.slice();
    pendingPosts = [];
    var send = senderFn;
    if (!send) {
      send =
        typeof global.PaletteHostAdapter !== "undefined" && global.PaletteHostAdapter.send
          ? function (payload) {
              global.PaletteHostAdapter.send("palette_perf_event", payload);
            }
          : function (payload) {
              try {
                if (global.chrome && global.chrome.webview && global.chrome.webview.postMessage) {
                  global.chrome.webview.postMessage(JSON.stringify(payload));
                }
              } catch (_) {}
            };
    }
    for (var i = 0; i < batch.length; i++) {
      try {
        send(batch[i]);
      } catch (_) {}
    }
  }

  function mark(name, extra) {
    var key = String(name || "");
    if (!key) return;
    var t = nowMs();
    marks[key] = t;
    try {
      if (typeof performance !== "undefined" && typeof performance.mark === "function") {
        performance.mark("palette:" + key);
      }
    } catch (_) {}
    queuePost(key, extra || {});
  }

  function measure(name, startName, endName, extra) {
    var start = marks[String(startName || "")];
    var end = marks[String(endName || "")];
    if (start == null || end == null) return 0;
    var dur = Math.max(0, end - start);
    try {
      if (typeof performance !== "undefined" && typeof performance.measure === "function") {
        performance.measure("palette:" + name, "palette:" + startName, "palette:" + endName);
      }
    } catch (_) {}
    var payload = extra && typeof extra === "object" ? Object.assign({}, extra) : {};
    payload.durationMs = dur;
    queuePost(String(name || startName + "_to_" + endName), payload);
    return dur;
  }

  function elapsedSince(name) {
    var start = marks[String(name || "")];
    if (start == null) return 0;
    return Math.max(0, nowMs() - start);
  }

  function markFirstInput(extra) {
    if (firstInputDone) return;
    firstInputDone = true;
    mark("first_input", extra || {});
  }

  function setSender(fn) {
    if (typeof fn === "function") senderFn = fn;
  }

  global.PalettePerfMarks = {
    sessionId: sessionId,
    mark: mark,
    measure: measure,
    elapsedSince: elapsedSince,
    markFirstInput: markFirstInput,
    setSender: setSender,
    flush: flushPosts
  };
})(typeof window !== "undefined" ? window : globalThis);
