/**
 * PaletteA2UIMetrics — A2UI 灰度可观测性（nmer-a2ui-error-v1 §5.3）
 * a2ui_error_total{code} · a2ui_fallback_total{hint} · a2ui_action_result_total{status}
 */
(function (root) {
  var MAX_RECENT = 32;

  var counters = {
    errorByCode: Object.create(null),
    fallbackByHint: Object.create(null),
    actionByStatus: Object.create(null),
    grayByRoute: Object.create(null),
    grayByReason: Object.create(null)
  };
  var recent = [];

  function bump(bucket, key) {
    var k = String(key || "unknown");
    bucket[k] = (bucket[k] || 0) + 1;
  }

  function sumBucket(bucket) {
    var total = 0;
    Object.keys(bucket).forEach(function (k) {
      total += bucket[k] || 0;
    });
    return total;
  }

  function cloneBucket(bucket) {
    var out = Object.create(null);
    Object.keys(bucket).forEach(function (k) {
      out[k] = bucket[k];
    });
    return out;
  }

  function pushRecent(evt) {
    recent.push(evt);
    if (recent.length > MAX_RECENT) recent.shift();
  }

  function normalizeError(input) {
    input = input || {};
    var err = input.error && typeof input.error === "object" ? input.error : input;
    var ctx = err.context && typeof err.context === "object" ? err.context : {};
    return {
      code: String(err.code || input.code || "UNKNOWN_A2UI_ERROR"),
      message: String(err.message || input.message || ""),
      layer: String(err.layer || input.layer || "unknown"),
      retryable: !!(err.retryable || input.retryable),
      cardId: String(ctx.cardId || input.cardId || ""),
      surfaceId: String(ctx.surfaceId || input.surfaceId || ""),
      seq: ctx.seq != null ? ctx.seq : input.seq,
      source: String(input.source || "unknown")
    };
  }

  function recordError(input) {
    var evt = normalizeError(input);
    bump(counters.errorByCode, evt.code);
    pushRecent(Object.assign({ evt: "a2ui_error" }, evt));
    emit("a2ui_error", evt);
    return evt;
  }

  function recordFallback(input) {
    input = input || {};
    var hint = String(input.hint || input.reason || "unknown");
    bump(counters.fallbackByHint, hint);
    var evt = {
      evt: "a2ui_fallback",
      hint: hint,
      cardId: String(input.cardId || ""),
      source: String(input.source || "unknown")
    };
    pushRecent(evt);
    emit("a2ui_fallback", evt);
    return evt;
  }

  function recordActionResult(input) {
    input = input || {};
    var status = String(input.status || "unknown");
    bump(counters.actionByStatus, status);
    var evt = {
      evt: "a2ui_action_result",
      status: status,
      error: String(input.error || ""),
      requestId: String(input.requestId || ""),
      cardId: String(input.cardId || ""),
      source: String(input.source || "ws")
    };
    pushRecent(evt);
    emit("a2ui_action_result", evt);
    return evt;
  }

  function recordGrayRoute(input) {
    input = input || {};
    var route = String(input.route || "r1r2");
    var reason = String(input.reason || "unknown");
    bump(counters.grayByRoute, route);
    bump(counters.grayByReason, reason);
    var evt = {
      evt: "official_a2ui_gray",
      route: route,
      reason: reason,
      command: String(input.command || ""),
      allowed: !!input.allowed
    };
    pushRecent(evt);
    emit("official_a2ui_gray", evt);
    return evt;
  }

  function emit(name, detail) {
    if (!root.document || typeof root.CustomEvent !== "function") return;
    try {
      document.dispatchEvent(new CustomEvent("palette-a2ui-metrics", { detail: { name: name, payload: detail } }));
    } catch (_) {}
  }

  function snapshot() {
    return {
      errors: sumBucket(counters.errorByCode),
      errorByCode: cloneBucket(counters.errorByCode),
      fallbacks: sumBucket(counters.fallbackByHint),
      fallbackByHint: cloneBucket(counters.fallbackByHint),
      actions: sumBucket(counters.actionByStatus),
      actionByStatus: cloneBucket(counters.actionByStatus),
      grayRoutes: sumBucket(counters.grayByRoute),
      grayByRoute: cloneBucket(counters.grayByRoute),
      grayByReason: cloneBucket(counters.grayByReason),
      recent: recent.slice()
    };
  }

  function formatCounterLines(bucket, prefix) {
    var keys = Object.keys(bucket).sort();
    if (!keys.length) return [];
    return keys.map(function (k) {
      return prefix + "{" + k + "}=" + bucket[k];
    });
  }

  function formatSummaryLines(snap) {
    snap = snap || snapshot();
    var lines = [];
    lines.push("errors=" + (snap.errors || 0));
    lines = lines.concat(formatCounterLines(snap.errorByCode || {}, "a2ui_error_total"));
    lines.push("fallbacks=" + (snap.fallbacks || 0));
    lines = lines.concat(formatCounterLines(snap.fallbackByHint || {}, "a2ui_fallback_total"));
    lines.push("actions=" + (snap.actions || 0));
    lines = lines.concat(formatCounterLines(snap.actionByStatus || {}, "a2ui_action_result_total"));
    lines.push("gray=" + (snap.grayRoutes || 0));
    lines = lines.concat(formatCounterLines(snap.grayByRoute || {}, "gray_route"));
    lines = lines.concat(formatCounterLines(snap.grayByReason || {}, "gray_reason"));
    return lines;
  }

  function resetForTest() {
    counters.errorByCode = Object.create(null);
    counters.fallbackByHint = Object.create(null);
    counters.actionByStatus = Object.create(null);
    counters.grayByRoute = Object.create(null);
    counters.grayByReason = Object.create(null);
    recent = [];
  }

  root.PaletteA2UIMetrics = {
    recordError: recordError,
    recordFallback: recordFallback,
    recordActionResult: recordActionResult,
    recordGrayRoute: recordGrayRoute,
    snapshot: snapshot,
    formatSummaryLines: formatSummaryLines,
    _resetForTest: resetForTest
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
