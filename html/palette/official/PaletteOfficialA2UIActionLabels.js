/**
 * PaletteOfficialA2UIActionLabels — Action 回执与 WS 拒收的用户可见文案（Wave 2）
 */
(function (root) {
  var STATUS_LABELS = {
    accepted: "已受理",
    completed: "已完成",
    rejected: "已拒绝",
    timeout: "已超时",
    cancelled: "已取消"
  };

  var GRAY_REASON_LABELS = {
    force_nmer_only: "强制 R1+R2",
    official_disabled: "官方 A2UI 未开启",
    bridge_not_healthy: "sidecar 未就绪",
    no_slash_command: "非斜杠命令",
    whitelist_empty: "白名单为空",
    not_whitelisted: "命令未入白名单",
    whitelist_hit: "R3 灰度命中"
  };

  function pickString() {
    for (var i = 0; i < arguments.length; i++) {
      var v = arguments[i];
      if (v === undefined || v === null) continue;
      var s = String(v).trim();
      if (s) return s;
    }
    return "";
  }

  function parseErrorObject(err) {
    if (!err) return null;
    if (typeof err === "string") {
      try {
        return JSON.parse(err);
      } catch (_) {
        return { message: err };
      }
    }
    return typeof err === "object" ? err : null;
  }

  function formatErrorCode(err) {
    var obj = parseErrorObject(err);
    if (!obj) return "";
    return pickString(obj.code, obj.errorCode);
  }

  function formatErrorMessage(err) {
    var obj = parseErrorObject(err);
    if (!obj) return pickString(err);
    var code = pickString(obj.code, obj.errorCode);
    var msg = pickString(obj.message, obj.error, obj.userMessage);
    if (code && msg) return code + " · " + msg;
    return pickString(code, msg);
  }

  function formatActionStatus(status) {
    var key = String(status || "").toLowerCase();
    return STATUS_LABELS[key] || (key ? key : "未知");
  }

  function formatGrayReason(reason) {
    var key = String(reason || "");
    return GRAY_REASON_LABELS[key] || key || "—";
  }

  function formatActionResult(result) {
    result = result || {};
    var status = String(result.status || "unknown").toLowerCase();
    var label = formatActionStatus(status);
    var code = pickString(result.errorCode, formatErrorCode(result.error));
    var detail = pickString(result.error, formatErrorMessage(result.error));
    var ok = status === "accepted" || status === "completed";
    var title = "[A2UI 操作] " + label;
    var body = code ? code + (detail ? " — " + detail : "") : detail;
    if (!body) body = status;
    return {
      ok: ok,
      status: status,
      title: title,
      body: body,
      tone: ok ? "success" : status === "cancelled" ? "muted" : "warn"
    };
  }

  function formatRejected(frame) {
    frame = frame || {};
    var err = frame.error || {};
    var code = pickString(err.code, frame.code);
    var msg = pickString(err.message, frame.reason, err.error);
    var layer = pickString(err.layer);
    var title = "[A2UI 拒收]";
    var body = code ? code + (msg ? " · " + msg : "") : pickString(msg, "unknown");
    if (layer) body += " (" + layer + ")";
    return {
      ok: false,
      code: code || "UNKNOWN",
      title: title,
      body: body,
      tone: "warn"
    };
  }

  function formatGrayDecision(decision) {
    decision = decision || {};
    var route = String(decision.route || "r1r2");
    var reason = formatGrayReason(decision.reason);
    return {
      route: route,
      reason: String(decision.reason || ""),
      label: route === "r3" ? "R3" : "R1+R2",
      detail: reason
    };
  }

  root.PaletteOfficialA2UIActionLabels = {
    STATUS_LABELS: STATUS_LABELS,
    GRAY_REASON_LABELS: GRAY_REASON_LABELS,
    formatActionStatus: formatActionStatus,
    formatGrayReason: formatGrayReason,
    formatErrorCode: formatErrorCode,
    formatErrorMessage: formatErrorMessage,
    formatActionResult: formatActionResult,
    formatRejected: formatRejected,
    formatGrayDecision: formatGrayDecision
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
