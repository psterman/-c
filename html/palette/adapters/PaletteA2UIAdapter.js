/**
 * PaletteA2UIAdapter — legacy/canonical component data → canonical A2UI block.
 *
 * Pure data boundary. No DOM access, rendering, provider branching, or action execution.
 */
(function (root) {
  var COMPONENTS = ["ComparisonTable", "Steps", "Alert", "ActionChips"];

  function isObject(value) {
    return !!value && typeof value === "object" && !Array.isArray(value);
  }

  function normalizeComparisonTable(raw) {
    raw = isObject(raw) ? raw : {};
    return {
      columns: Array.isArray(raw.columns)
        ? raw.columns
        : Array.isArray(raw.headers)
          ? raw.headers
          : [],
      rows: Array.isArray(raw.rows)
        ? raw.rows
        : Array.isArray(raw.data)
          ? raw.data
          : []
    };
  }

  function normalizeStepItem(item) {
    if (isObject(item)) {
      if (item.text != null) return item.text;
      if (item.title != null) return item.title;
      if (item.label != null) return item.label;
      return "";
    }
    return item;
  }

  function normalizeSteps(raw) {
    raw = isObject(raw) ? raw : {};
    var source = Array.isArray(raw.items)
      ? raw.items
      : Array.isArray(raw.steps)
        ? raw.steps
        : [];
    return {
      items: source.map(normalizeStepItem)
    };
  }

  function normalizeAlert(raw) {
    raw = isObject(raw) ? raw : {};
    return {
      variant: raw.variant != null ? raw.variant : raw.severity,
      text: raw.text != null ? raw.text : raw.message
    };
  }

  function normalizeActionChips(raw) {
    raw = isObject(raw) ? raw : {};
    return {
      actions: Array.isArray(raw.actions)
        ? raw.actions
        : Array.isArray(raw.chips)
          ? raw.chips
          : []
    };
  }

  var ADAPTERS = {
    ComparisonTable: normalizeComparisonTable,
    Steps: normalizeSteps,
    Alert: normalizeAlert,
    ActionChips: normalizeActionChips
  };

  function trace(context, event, payload) {
    if (!context || typeof context.debugLog !== "function") return;
    try {
      context.debugLog(event, typeof payload === "string" ? payload : JSON.stringify(payload));
    } catch (_) {}
  }

  function genBlockId(component, context) {
    if (context && (context.id || context.blockId)) return String(context.id || context.blockId);
    if (root.PaletteBlockSchema && PaletteBlockSchema.genBlockId) {
      return PaletteBlockSchema.genBlockId("blk_" + String(component || "a2ui").toLowerCase());
    }
    return "blk_a2ui_" + Date.now();
  }

  function createBlock(component, rawProps, context) {
    context = context || {};
    var comp = String(component || "").trim();
    var adapt = ADAPTERS[comp];
    if (!adapt) {
      trace(context, "a2ui_adapter_rejected", {
        component: comp,
        reason: "unsupported_component"
      });
      return null;
    }

    var block = {
      id: genBlockId(comp, context),
      type: "a2ui",
      state: context.state || "final",
      source: context.source || "system",
      confidence: context.confidence != null ? Number(context.confidence) : 1,
      seq: context.seq != null ? Number(context.seq) : 0,
      turnId: context.turnId != null ? Number(context.turnId) : 1,
      traceId: context.traceId || "",
      schemaVersion:
        root.PaletteBlockSchema && PaletteBlockSchema.A2UI_SCHEMA_VERSION
          ? PaletteBlockSchema.A2UI_SCHEMA_VERSION
          : 1,
      component: comp,
      props: adapt(rawProps)
    };

    if (root.PaletteBlockSchema && PaletteBlockSchema.sanitizeBlock) {
      block = PaletteBlockSchema.sanitizeBlock(block);
    }
    if (!block) {
      trace(context, "a2ui_adapter_rejected", {
        component: comp,
        reason: "schema_rejected"
      });
      return null;
    }

    trace(context, "a2ui_adapter_created", {
      component: comp,
      blockId: block.id || "",
      schemaVersion: block.schemaVersion || 1
    });
    return block;
  }

  root.PaletteA2UIAdapter = {
    COMPONENTS: COMPONENTS,
    ADAPTERS: ADAPTERS,
    createBlock: createBlock,
    normalizeComparisonTable: normalizeComparisonTable,
    normalizeSteps: normalizeSteps,
    normalizeAlert: normalizeAlert,
    normalizeActionChips: normalizeActionChips
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
