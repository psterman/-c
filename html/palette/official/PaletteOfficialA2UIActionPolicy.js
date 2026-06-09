/**
 * PaletteOfficialA2UIActionPolicy — 客户端 Action 权限预检（对齐 Go A2UIActionPolicy）
 */
(function (root) {
  var ACTION_VERSION = "nmer.a2ui.action.v1";
  var ALLOWED_ACTIONS = ["safe.follow-up"];
  var MAX_DEPTH = 2;
  var MIN_TIMEOUT = 100;
  var MAX_TIMEOUT = 30000;

  function fail(code, message, field) {
    return {
      ok: false,
      code: code,
      message: message,
      field: field || ""
    };
  }

  function validate(action) {
    action = action || {};
    if (String(action.schemaVersion || "") !== ACTION_VERSION) {
      return fail("ACTION_VERSION_UNSUPPORTED", "unsupported action version");
    }
    var required = [
      "eventId", "requestId", "correlationId", "cardId",
      "surfaceId", "componentId", "actionName", "abortId"
    ];
    for (var i = 0; i < required.length; i++) {
      var key = required[i];
      if (!String(action[key] || "").trim()) {
        return fail("TPA_FIELD_REQUIRED", key + " is required", key);
      }
    }
    var name = String(action.actionName || "");
    if (ALLOWED_ACTIONS.indexOf(name) < 0) {
      return fail("ACTION_NOT_ALLOWED", "action not allowed: " + name, "actionName");
    }
    var depth = Number(action.depth || 0);
    if (!Number.isFinite(depth) || depth < 0 || depth > MAX_DEPTH) {
      return fail("ACTION_DEPTH_EXCEEDED", "depth out of range", "depth");
    }
    var timeoutMs = Number(action.timeoutMs || 0);
    if (!Number.isFinite(timeoutMs) || timeoutMs < MIN_TIMEOUT || timeoutMs > MAX_TIMEOUT) {
      return fail("ACTION_TIMEOUT_RANGE", "timeout out of range", "timeoutMs");
    }
    var data = action.data && typeof action.data === "object" ? action.data : {};
    if (String(data.kind || "") !== "safe") {
      return fail("ACTION_KIND_UNSAFE", "kind must be safe", "data.kind");
    }
    return { ok: true, code: "ACTION_OK" };
  }

  root.PaletteOfficialA2UIActionPolicy = {
    ACTION_VERSION: ACTION_VERSION,
    ALLOWED_ACTIONS: ALLOWED_ACTIONS,
    validate: validate
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
