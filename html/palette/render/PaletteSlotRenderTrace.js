/**
 * PaletteSlotRenderTrace — 卡片槽位渲染路径聚合（lit / legacy / fallback + per-block）
 */
(function (root) {
  var traces = {};
  var activeCardId = "";

  var TRACE_REASONS = {
    OK: "ok",
    INVALID_SCHEMA: "invalid_schema",
    UNKNOWN_BLOCK: "unknown_block",
    NO_LIT_COMPONENT: "no_lit_component",
    RENDER_ERROR: "render_error",
    UNSUPPORTED_ACTION: "unsupported_action"
  };

  var REASON_ALIASES = {
    "": "ok",
    lit_ok: "ok",
    render_exception: "render_error",
    lit_unavailable: "no_lit_component",
    component_not_registered: "no_lit_component",
    bridge_unavailable: "no_lit_component",
    invalid_descriptor: "invalid_schema",
    empty_actions: "invalid_schema",
    empty_chips: "invalid_schema",
    empty_entries: "invalid_schema"
  };

  function normalizeRenderReason(reason, renderer) {
    var r = String(reason != null ? reason : "").trim();
    if (REASON_ALIASES[r]) return REASON_ALIASES[r];
    if (!r) {
      if (renderer === "lit") return TRACE_REASONS.OK;
      if (renderer === "fallback") return TRACE_REASONS.RENDER_ERROR;
      return TRACE_REASONS.NO_LIT_COMPONENT;
    }
    return r;
  }

  function beginCardRender(cardId) {
    activeCardId = String(cardId || "");
    traces[activeCardId] = { _blocks: [] };
  }

  function mergeInfo(prev, info) {
    info = info || {};
    var renderer = String(info.renderer || (prev && prev.renderer) || "legacy");
    var reason = normalizeRenderReason(
      info.reason != null ? info.reason : prev && prev.reason != null ? prev.reason : "",
      renderer
    );
    var row = {
      cardId: String(info.cardId || (prev && prev.cardId) || activeCardId || ""),
      component: String(info.component || (prev && prev.component) || ""),
      renderer: renderer,
      reason: reason,
      count:
        prev
          ? (prev.count || 0) + (info.count != null ? Number(info.count) : 0)
          : info.count != null
            ? Number(info.count)
            : 0,
      blockId: info.blockId ? String(info.blockId) : prev && prev.blockId ? prev.blockId : ""
    };
    if (info.blockType) row.blockType = String(info.blockType);
    else if (prev && prev.blockType) row.blockType = prev.blockType;
    return row;
  }

  function pushBlockEntry(cardId, row) {
    if (!cardId || !traces[cardId]) return;
    if (!traces[cardId]._blocks) traces[cardId]._blocks = [];
    traces[cardId]._blocks.push({
      cardId: row.cardId || cardId,
      blockId: row.blockId || "",
      blockType: row.blockType || row.component || "",
      renderer: row.renderer || "legacy",
      reason: row.reason || TRACE_REASONS.NO_LIT_COMPONENT
    });
  }

  function record(slot, info) {
    slot = String(slot || "");
    if (!slot) return;
    var cardId = info && info.cardId ? String(info.cardId) : activeCardId;
    if (!cardId) return;
    if (!traces[cardId]) traces[cardId] = { _blocks: [] };
    var row = mergeInfo(traces[cardId][slot], Object.assign({ cardId: cardId }, info || {}));
    traces[cardId][slot] = row;
    if (row.blockId || row.blockType) pushBlockEntry(cardId, row);
  }

  function snapshot(cardId) {
    var id = cardId != null && cardId !== "" ? String(cardId) : activeCardId;
    if (!id || !traces[id]) return { blocks: [] };
    var out = { blocks: [] };
    var bucket = traces[id];
    Object.keys(bucket).forEach(function (key) {
      if (key === "_blocks") return;
      out[key] = Object.assign({}, bucket[key]);
    });
    out.blocks = (bucket._blocks || []).map(function (row) {
      return Object.assign({}, row);
    });
    return out;
  }

  function findBlock(cardId, blockId) {
    var snap = snapshot(cardId);
    if (!snap.blocks || !snap.blocks.length) return null;
    for (var i = 0; i < snap.blocks.length; i++) {
      if (snap.blocks[i].blockId === blockId) return snap.blocks[i];
    }
    return null;
  }

  root.PaletteSlotRenderTrace = {
    TRACE_REASONS: TRACE_REASONS,
    normalizeRenderReason: normalizeRenderReason,
    beginCardRender: beginCardRender,
    record: record,
    snapshot: snapshot,
    findBlock: findBlock
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
