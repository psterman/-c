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
  var A2UI_WHITELIST = ["ComparisonTable", "Steps", "Alert", "ActionChips"];
  var ACTION_CHIP_INTENTS = ["prefill", "submit", "inspect", "apply", "undo", "route"];
  var ACTION_CHIP_TONES = ["primary", "secondary", "muted", "danger"];
  var A2UI_SCHEMA_VERSION = 1;
  var ALERT_VARIANTS = ["info", "warning", "error", "success"];
  var LEGACY_INTENT_MAP = {
    append: "prefill",
    execute: "submit",
    prefill: "prefill",
    submit: "submit",
    inspect: "inspect",
    apply: "apply",
    undo: "undo",
    route: "route"
  };
  var LIMITS = {
    MAX_REPLY_MD: 20000,
    MAX_STATUS_TEXT: 8000,
    MAX_STATUS_ITEMS: 50,
    MAX_PLAN_ITEMS: 30,
    MAX_QUESTION_MD: 8000,
    MAX_TABLE_ROWS: 20,
    MAX_TABLE_COLS: 8,
    MAX_CELL: 500,
    MAX_BLOCKS: 40,
    MAX_STEPS: 20,
    MAX_ALERTS: 5,
    MAX_ACTION_CHIPS: 24,
    MAX_ACTION_CHIP_LABEL: 120,
    MAX_ACTION_CHIP_PAYLOAD_TEXT: 2000
  };
  var PLAN_ITEM_STATES = ["pending", "running", "done", "error", "interrupted"];
  var STATUS_LEVELS = ["info", "warning", "error"];
  var TOOL_EVENT_PHASES = ["start", "progress", "done", "error"];
  var ACTION_KINDS = ["safe", "confirm"];
  var QUESTION_STATUSES = ["waiting", "answered", "expired", "cancelled"];

  function clamp(n, lo, hi) {
    n = Number(n);
    if (isNaN(n)) return lo;
    return Math.max(lo, Math.min(hi, n));
  }

  function trimText(text, max) {
    var t = String(text != null ? text : "");
    if (t.length <= max) return t;
    return t.slice(0, max);
  }

  function clipComparisonTableProps(props) {
    props = props && typeof props === "object" && !Array.isArray(props) ? props : {};
    var rawCols = Array.isArray(props.columns) ? props.columns : [];
    var rawRows = Array.isArray(props.rows) ? props.rows : [];
    var origCols = rawCols.length;
    var origRows = rawRows.length;
    var cols = rawCols.slice(0, LIMITS.MAX_TABLE_COLS).map(function (c) {
      return trimText(c, LIMITS.MAX_CELL);
    });
    var rows = rawRows.slice(0, LIMITS.MAX_TABLE_ROWS).map(function (row) {
      if (!Array.isArray(row)) return null;
      return row.slice(0, LIMITS.MAX_TABLE_COLS).map(function (c) {
        return trimText(c, LIMITS.MAX_CELL);
      });
    }).filter(Boolean);
    var clipped = origCols > LIMITS.MAX_TABLE_COLS || origRows > LIMITS.MAX_TABLE_ROWS;
    return {
      props: { columns: cols, rows: rows },
      clipped: clipped,
      originalRows: origRows,
      originalCols: origCols
    };
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
      var row = { text: text.slice(0, LIMITS.MAX_STATUS_TEXT), level: lv };
      if (it.time != null) row.time = String(it.time).slice(0, 32);
      if (it.tool != null) row.tool = trimText(it.tool, 120);
      if (it.phase != null) {
        var ph = String(it.phase);
        if (TOOL_EVENT_PHASES.indexOf(ph) >= 0) row.phase = ph;
      }
      if (it.ts != null) row.ts = Number(it.ts) || Date.now();
      out.push(row);
    }
    return out;
  }

  function resolveActionChipIntent(rawIntent) {
    var raw = String(rawIntent != null ? rawIntent : "").trim();
    if (ACTION_CHIP_INTENTS.indexOf(raw) >= 0) return raw;
    if (raw && LEGACY_INTENT_MAP[raw]) return LEGACY_INTENT_MAP[raw];
    return "prefill";
  }

  function resolveActionChipPayloadText(action, label) {
    action = action || {};
    var text = action.text != null ? String(action.text).trim() : "";
    if (!text && action.prompt != null) text = String(action.prompt).trim();
    if (!text && action.prefill != null) text = String(action.prefill).trim();
    if (!text) text = String(label || "").trim();
    return trimText(text, LIMITS.MAX_ACTION_CHIP_PAYLOAD_TEXT);
  }

  function sanitizeActionChip(action, index) {
    if (!action || typeof action !== "object") return null;
    var label = String(action.label != null ? action.label : "").trim();
    if (!label) return null;
    var id = String(action.id != null ? action.id : "").trim();
    if (!id) id = "action_" + String((index != null ? index : 0) + 1);
    var row = {
      id: id.slice(0, 64),
      label: label.slice(0, LIMITS.MAX_ACTION_CHIP_LABEL),
      intent: resolveActionChipIntent(action.intent),
      payload: { text: resolveActionChipPayloadText(action, label) }
    };
    if (action.disabled) row.disabled = true;
    var tone = String(action.tone != null ? action.tone : "").trim();
    if (tone && ACTION_CHIP_TONES.indexOf(tone) >= 0) row.tone = tone;
    if (action.payload && typeof action.payload === "object" && !Array.isArray(action.payload)) {
      try {
        var extra = JSON.parse(JSON.stringify(action.payload));
        if (extra.text == null && row.payload && row.payload.text) extra.text = row.payload.text;
        row.payload = extra;
        if (row.payload.text != null) {
          row.payload.text = trimText(row.payload.text, LIMITS.MAX_ACTION_CHIP_PAYLOAD_TEXT);
        }
      } catch (_) {}
    }
    return row;
  }

  function sanitizeActionChipsProps(props) {
    props = props || {};
    var raw = Array.isArray(props.actions) ? props.actions : [];
    var actions = [];
    for (var i = 0; i < raw.length && actions.length < LIMITS.MAX_ACTION_CHIPS; i++) {
      var row = sanitizeActionChip(raw[i], i);
      if (row) actions.push(row);
    }
    return { actions: actions };
  }

  function sanitizeStepsProps(props) {
    props = props && typeof props === "object" && !Array.isArray(props) ? props : {};
    var raw = Array.isArray(props.items) ? props.items : [];
    var items = [];
    for (var i = 0; i < raw.length && items.length < LIMITS.MAX_STEPS; i++) {
      var text = trimText(raw[i], 2000).trim();
      if (text) items.push(text);
    }
    return { items: items };
  }

  function sanitizeAlertProps(props) {
    props = props && typeof props === "object" && !Array.isArray(props) ? props : {};
    var variant = String(props.variant || "info").trim();
    if (ALERT_VARIANTS.indexOf(variant) < 0) variant = "info";
    return {
      variant: variant,
      text: trimText(props.text, 2000).trim()
    };
  }

  function sanitizeA2UIProps(component, props) {
    var comp = String(component || "");
    if (comp === "ComparisonTable") return clipComparisonTableProps(props).props;
    if (comp === "Steps") return sanitizeStepsProps(props);
    if (comp === "Alert") return sanitizeAlertProps(props);
    if (comp === "ActionChips") return sanitizeActionChipsProps(props);
    return sanitizeProps(props);
  }

  function sanitizeActions(actions) {
    if (!Array.isArray(actions)) return [];
    var out = [];
    for (var i = 0; i < actions.length; i++) {
      var a = actions[i];
      if (!a || typeof a !== "object") continue;
      var id = String(a.id || "").trim();
      var label = String(a.label || "").trim();
      if (!id || !label) continue;
      var kind = String(a.kind || "safe");
      if (ACTION_KINDS.indexOf(kind) < 0) kind = "safe";
      var row = {
        id: id.slice(0, 64),
        label: label.slice(0, 120),
        kind: kind,
        disabled: !!a.disabled
      };
      if (a.intent != null) row.intent = String(a.intent).slice(0, 64);
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
      out.schemaVersion = Number(block.schemaVersion) || A2UI_SCHEMA_VERSION;
      if (comp === "ActionChips") {
        var chipProps = sanitizeA2UIProps(comp, block.props);
        if (!chipProps.actions.length) return null;
        out.props = chipProps;
      } else {
        out.props = sanitizeA2UIProps(comp, block.props);
      }
    } else if (type === "error") {
      out.message = String(block.message || "任务失败").slice(0, 2000);
      if (block.code != null) out.code = String(block.code).slice(0, 64);
    }

    if (Array.isArray(block.actions) && block.actions.length) {
      out.actions = sanitizeActions(block.actions);
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
    A2UI_SCHEMA_VERSION: A2UI_SCHEMA_VERSION,
    ALERT_VARIANTS: ALERT_VARIANTS,
    ACTION_CHIP_INTENTS: ACTION_CHIP_INTENTS,
    ACTION_CHIP_TONES: ACTION_CHIP_TONES,
    ACTION_CHIPS_COMPONENT: "ActionChips",
    LIMITS: LIMITS,
    resolveActionChipIntent: resolveActionChipIntent,
    resolveActionChipPayloadText: resolveActionChipPayloadText,
    sanitizeActionChip: sanitizeActionChip,
    sanitizeActionChipsProps: sanitizeActionChipsProps,
    sanitizeStepsProps: sanitizeStepsProps,
    sanitizeAlertProps: sanitizeAlertProps,
    sanitizeA2UIProps: sanitizeA2UIProps,
    TOOL_EVENT_PHASES: TOOL_EVENT_PHASES,
    ACTION_KINDS: ACTION_KINDS,
    trimText: trimText,
    clipComparisonTableProps: clipComparisonTableProps,
    sanitizeActions: sanitizeActions,
    validateBlock: validateBlock,
    validateBlocks: validateBlocks,
    sanitizeBlock: sanitizeBlock,
    genBlockId: genId
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
