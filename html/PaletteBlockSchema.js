/**
 * Palette blocks[] 校验与消毒（schema v1）
 */
(function (root) {
  var BLOCK_TYPES = ["plan", "status", "question", "reply", "a2ui", "error"];
  var BLOCK_STATES = ["streaming", "final", "stale"];
  var BLOCK_SOURCES = [
    "protocol",
    "heuristic",
    "markdown",
    "markdown_table",
    "tool_event",
    "raw",
    "system"
  ];
  var A2UI_WHITELIST = ["ComparisonTable", "Steps", "Alert"];
  var PLAN_ITEM_STATES = ["pending", "running", "done", "error", "interrupted"];
  var STATUS_LEVELS = ["info", "warning", "error"];
  var QUESTION_STATUSES = ["waiting", "answered", "expired", "cancelled"];

  function clamp(n, lo, hi) {
    n = Number(n);
    if (isNaN(n)) return lo;
    return Math.max(lo, Math.min(hi, n));
  }

  function genId(prefix) {
    return (
      String(prefix || "blk") +
      "_" +
      Date.now().toString(36) +
      "_" +
      Math.random().toString(36).slice(2, 8)
    );
  }

  function validateBlock(block) {
    var errors = [];
    if (!block || typeof block !== "object") {
      return { ok: false, errors: ["block_not_object"] };
    }
    var type = String(block.type || "");
    if (BLOCK_TYPES.indexOf(type) < 0) errors.push("invalid_type:" + type);
    var state = String(block.state || "final");
    if (BLOCK_STATES.indexOf(state) < 0) errors.push("invalid_state:" + state);
    var source = String(block.source || "raw");
    if (BLOCK_SOURCES.indexOf(source) < 0) errors.push("invalid_source:" + source);
    if (type === "a2ui") {
      var comp = String(block.component || "");
      if (A2UI_WHITELIST.indexOf(comp) < 0) errors.push("unsupported_component:" + comp);
    }
    return { ok: errors.length === 0, errors: errors };
  }

  function sanitizePlanItems(items) {
    if (!Array.isArray(items)) return [];
    var out = [];
    for (var i = 0; i < items.length; i++) {
      var it = items[i];
      if (!it || typeof it !== "object") continue;
      var text = String(it.text != null ? it.text : "").trim();
      if (!text) continue;
      var st = String(it.state || "done");
      if (PLAN_ITEM_STATES.indexOf(st) < 0) st = "done";
      out.push({ text: text.slice(0, 2000), state: st });
    }
    return out;
  }

  function sanitizeStatusItems(items) {
    if (!Array.isArray(items)) return [];
    var out = [];
    for (var i = 0; i < items.length; i++) {
      var it = items[i];
      if (!it || typeof it !== "object") continue;
      var text = String(it.text != null ? it.text : "").trim();
      if (!text) continue;
      var lv = String(it.level || "info");
      if (STATUS_LEVELS.indexOf(lv) < 0) lv = "info";
      var row = { text: text.slice(0, 8000), level: lv };
      if (it.time != null) row.time = String(it.time).slice(0, 32);
      out.push(row);
    }
    return out;
  }

  function sanitizeProps(props) {
    if (!props || typeof props !== "object" || Array.isArray(props)) return {};
    try {
      return JSON.parse(JSON.stringify(props));
    } catch (_) {
      return {};
    }
  }

  function sanitizeBlock(block) {
    if (!block || typeof block !== "object") return null;
    var type = String(block.type || "");
    if (BLOCK_TYPES.indexOf(type) < 0) return null;

    var now = Date.now();
    var out = {
      id: String(block.id || genId("blk")),
      type: type,
      state: BLOCK_STATES.indexOf(String(block.state || "")) >= 0 ? String(block.state) : "final",
      source: BLOCK_SOURCES.indexOf(String(block.source || "")) >= 0 ? String(block.source) : "raw",
      confidence: clamp(block.confidence != null ? block.confidence : 0.8, 0, 1),
      seq: Number(block.seq) || 0,
      turnId: Number(block.turnId) || 1,
      traceId: String(block.traceId || ""),
      createdAt: Number(block.createdAt) || now,
      updatedAt: Number(block.updatedAt) || now
    };

    if (type === "plan") {
      out.items = sanitizePlanItems(block.items);
      if (!out.items.length) return null;
    } else if (type === "status") {
      out.items = sanitizeStatusItems(block.items);
      if (!out.items.length) return null;
    } else if (type === "question") {
      out.title = String(block.title || "需要您的确认").slice(0, 200);
      out.markdown = String(block.markdown != null ? block.markdown : block.content || "").slice(0, 12000);
      var qs = String(block.status || "waiting");
      out.status = QUESTION_STATUSES.indexOf(qs) >= 0 ? qs : "waiting";
      if (block.answerTurnId != null) out.answerTurnId = block.answerTurnId;
    } else if (type === "reply") {
      out.markdown = String(block.markdown != null ? block.markdown : block.content || block.body || "").slice(
        0,
        12000
      );
      if (block.title != null) out.title = String(block.title).slice(0, 200);
      if (block.truncated) out.truncated = true;
      if (block.rawRef) out.rawRef = String(block.rawRef);
      if (!out.markdown.trim()) return null;
    } else if (type === "a2ui") {
      var comp = String(block.component || "");
      if (A2UI_WHITELIST.indexOf(comp) < 0) return null;
      out.component = comp;
      out.props = sanitizeProps(block.props);
    } else if (type === "error") {
      out.message = String(block.message || "任务失败").slice(0, 2000);
      if (block.code != null) out.code = String(block.code).slice(0, 64);
    }

    return out;
  }

  function validateBlocks(blocks) {
    var list = Array.isArray(blocks) ? blocks : [];
    var safe = [];
    var errors = [];
    var dropped = [];
    for (var i = 0; i < list.length; i++) {
      var raw = list[i];
      var v = validateBlock(raw);
      var s = sanitizeBlock(raw);
      if (!s) {
        dropped.push(raw);
        if (!v.ok) errors = errors.concat(v.errors);
        continue;
      }
      if (!v.ok) errors = errors.concat(v.errors);
      safe.push(s);
    }
    safe.sort(function (a, b) {
      return (a.seq || 0) - (b.seq || 0);
    });
    return { ok: errors.length === 0, blocks: safe, errors: errors, dropped: dropped };
  }

  root.PaletteBlockSchema = {
    BLOCK_VERSION: 1,
    NORMALIZER_VERSION: "2026-06-06",
    A2UI_WHITELIST: A2UI_WHITELIST,
    validateBlock: validateBlock,
    validateBlocks: validateBlocks,
    sanitizeBlock: sanitizeBlock,
    genBlockId: genId
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
