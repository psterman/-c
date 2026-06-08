/**
 * PaletteUIEventContract — palette-action 事件契约 v2
 * normalizeAction：仅 action { type, value }
 * normalizePaletteAction：完整 detail 信封；source/prefill 仅作 v1 兼容输入
 */
(function (root) {
  var ACTION_KIND = { chipClick: "chip_click" };
  var ACTION_TYPES = { prefill: "prefill", submit: "submit", noop: "noop" };
  var RENDERERS = { lit: "lit", legacy: "legacy" };
  var COMPONENT_IDS = { followUpChips: "follow-up-chips" };
  var SLOT_IDS = { actions: "actions" };
  var DATA_SOURCES = {
    merged: "merged",
    replyActions: "reply.actions",
    routeProfile: "routeProfile.followUpChips"
  };

  function normalizeRenderer(raw) {
    if (raw === RENDERERS.lit || raw === RENDERERS.legacy) return raw;
    return RENDERERS.legacy;
  }

  /** v1 兼容：source 曾误用作 renderer */
  function compatRenderer(detail) {
    detail = detail || {};
    if (detail.renderer != null && detail.renderer !== "") {
      return normalizeRenderer(detail.renderer);
    }
    if (detail.source === RENDERERS.lit || detail.source === RENDERERS.legacy) {
      return normalizeRenderer(detail.source);
    }
    return RENDERERS.legacy;
  }

  /** 仅规范化 action 载荷 { type, value } */
  function normalizeAction(raw) {
    raw = raw || {};
    var type = raw.type ? String(raw.type) : ACTION_TYPES.prefill;
    return {
      type: type,
      value: String(raw.value != null ? raw.value : "")
    };
  }

  /** 从 detail/chip 提取 action 原始输入（含 v1 prefill 兼容） */
  function extractActionRaw(detail, chip) {
    detail = detail || {};
    chip = chip || {};
    if (detail.action && (detail.action.type || detail.action.value != null)) {
      return {
        type: detail.action.type || ACTION_TYPES.prefill,
        value:
          detail.action.value != null
            ? detail.action.value
            : detail.prefill != null
              ? detail.prefill
              : chip.prefill || chip.label || ""
      };
    }
    if (chip.action && (chip.action.type || chip.action.value != null)) {
      return {
        type: chip.action.type || ACTION_TYPES.prefill,
        value: chip.action.value != null ? chip.action.value : chip.prefill || chip.label || ""
      };
    }
    if (detail.prefill != null) {
      return { type: ACTION_TYPES.prefill, value: detail.prefill };
    }
    return {
      type: ACTION_TYPES.prefill,
      value: chip.prefill || chip.label || ""
    };
  }

  function normalizeChipRef(detail) {
    detail = detail || {};
    var chip = detail.chip || {};
    var chipId = String(detail.chipId || chip.id || "");
    if (!chipId) return { id: "", label: "" };
    return {
      id: chipId,
      label: String(chip.label || chip.id || "")
    };
  }

  function buildChipClickDetail(params) {
    params = params || {};
    var chipRef = normalizeChipRef({
      chipId: params.chipId,
      chip: params.chip || {}
    });
    var action = normalizeAction(
      params.action || {
        type: ACTION_TYPES.prefill,
        value:
          (params.chip && params.chip.action && params.chip.action.value) ||
          (params.chip && params.chip.prefill) ||
          params.chip.label ||
          ""
      }
    );
    return normalizePaletteAction({
      kind: ACTION_KIND.chipClick,
      cardId: params.cardId,
      chipId: chipRef.id,
      chip: chipRef,
      action: action,
      dataSource: params.dataSource || DATA_SOURCES.merged,
      renderer: params.renderer != null ? params.renderer : compatRenderer(params),
      component: params.component || COMPONENT_IDS.followUpChips,
      slot: params.slot || SLOT_IDS.actions,
      intent: (params.chip && params.chip.intent) || params.intent || "append"
    });
  }

  /** 完整 palette-action detail；输出不含 source / prefill */
  function normalizePaletteAction(detail) {
    detail = detail || {};
    var chipRef = normalizeChipRef(detail);
    var action = normalizeAction(extractActionRaw(detail, detail.chip || chipRef));
    if (!chipRef.label && action.value) chipRef.label = String(action.value).slice(0, 40);
    return {
      kind: detail.kind || ACTION_KIND.chipClick,
      component: detail.component || COMPONENT_IDS.followUpChips,
      slot: detail.slot || SLOT_IDS.actions,
      cardId: String(detail.cardId || ""),
      chipId: chipRef.id,
      chip: chipRef,
      action: action,
      dataSource: detail.dataSource || DATA_SOURCES.merged,
      renderer: compatRenderer(detail),
      intent: detail.intent || "append"
    };
  }

  function isValidAction(action) {
    action = normalizeAction(action);
    if (action.type === ACTION_TYPES.submit) return false;
    if (action.type === ACTION_TYPES.noop) return false;
    if (action.type === ACTION_TYPES.prefill && !String(action.value || "").trim()) return false;
    if (action.type !== ACTION_TYPES.prefill) return false;
    return true;
  }

  function isValidPaletteAction(detail) {
    detail = normalizePaletteAction(detail);
    if (!detail.cardId || !detail.chipId) return false;
    if (detail.kind && detail.kind !== ACTION_KIND.chipClick) return false;
    return isValidAction(detail.action);
  }

  function getRejectReason(detail) {
    detail = normalizePaletteAction(detail);
    if (!detail.cardId || !detail.chipId) return "invalid_action";
    if (!detail.action || !detail.action.type) return "invalid_action";
    if (detail.action.type === ACTION_TYPES.prefill && !String(detail.action.value || "").trim()) {
      return "missing_prefill_value";
    }
    if (detail.action.type === ACTION_TYPES.submit) return "submit_not_wired";
    if (detail.action.type === ACTION_TYPES.noop) return "noop_not_wired";
    return "invalid_action";
  }

  root.PaletteUIEventContract = {
    ACTION_KIND: ACTION_KIND,
    ACTION_TYPES: ACTION_TYPES,
    RENDERERS: RENDERERS,
    COMPONENT_IDS: COMPONENT_IDS,
    SLOT_IDS: SLOT_IDS,
    DATA_SOURCES: DATA_SOURCES,
    normalizeAction: normalizeAction,
    normalizePaletteAction: normalizePaletteAction,
    buildChipClickDetail: buildChipClickDetail,
    isValidAction: isValidAction,
    isValidPaletteAction: isValidPaletteAction,
    getRejectReason: getRejectReason
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
