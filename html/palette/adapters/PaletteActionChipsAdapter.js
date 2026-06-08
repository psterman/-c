/**
 * PaletteActionChipsAdapter — reply.actions / followUpChips → ActionChips a2ui block
 *
 * 纯数据规范化；不含事件绑定或 DOM 渲染。
 */
(function (root) {
  var COMPONENT = "ActionChips";

  function trace(context, event, payload) {
    if (!context || typeof context.debugLog !== "function") return;
    try {
      context.debugLog(event, typeof payload === "string" ? payload : JSON.stringify(payload));
    } catch (_) {}
  }

  function genBlockId(context) {
    if (context && context.blockId) return String(context.blockId);
    if (root.PaletteBlockSchema && PaletteBlockSchema.genBlockId) {
      return PaletteBlockSchema.genBlockId("blk_action_chips");
    }
    return "blk_action_chips_" + Date.now();
  }

  function collectSourceActions(replyActions, context) {
    var list = [];
    if (Array.isArray(replyActions)) list = list.concat(replyActions);
    if (context && Array.isArray(context.followUpChips)) list = list.concat(context.followUpChips);
    return list;
  }

  function normalizeRawActions(rawList, context) {
    var sanitized = [];
    var invalid = 0;
    var sanitize =
      root.PaletteBlockSchema && PaletteBlockSchema.sanitizeActionChip
        ? PaletteBlockSchema.sanitizeActionChip
        : null;

    for (var i = 0; i < rawList.length; i++) {
      var raw = rawList[i];
      if (!raw || typeof raw !== "object") {
        invalid++;
        continue;
      }
      var label = String(raw.label != null ? raw.label : "").trim();
      if (!label) {
        invalid++;
        trace(context, "action_chips_invalid_action", {
          index: i,
          reason: "missing_label",
          id: raw.id || ""
        });
        continue;
      }
      var row = sanitize ? sanitize(raw, i) : null;
      if (!row) {
        invalid++;
        trace(context, "action_chips_invalid_action", {
          index: i,
          reason: "sanitize_failed",
          id: raw.id || ""
        });
        continue;
      }
      sanitized.push(row);
    }

    return { actions: sanitized, invalidCount: invalid };
  }

  function dedupeActions(actions) {
    var out = [];
    var seen = {};
    for (var i = 0; i < actions.length; i++) {
      var a = actions[i];
      if (!a || !a.id || seen[a.id]) continue;
      seen[a.id] = true;
      out.push(a);
    }
    return out;
  }

  /**
   * @param {Array} replyActions reply.actions 或已合并的 action 列表
   * @param {object} [context] cardId, followUpChips, blockId, seq, turnId, traceId, debugLog
   * @returns {object|null} 标准 a2ui ActionChips block；无有效 action 时返回 null
   */
  function normalizeFollowUpActionsToActionChips(replyActions, context) {
    context = context || {};
    try {
      var rawList = collectSourceActions(replyActions, context);
      if (!rawList.length) {
        trace(context, "action_chips_empty", {
          cardId: context.cardId || "",
          reason: "no_source_actions"
        });
        return null;
      }

      var normalized = normalizeRawActions(rawList, context);
      var actions = dedupeActions(normalized.actions);
      if (!actions.length) {
        trace(context, "action_chips_empty", {
          cardId: context.cardId || "",
          reason: "all_invalid",
          invalidCount: normalized.invalidCount
        });
        return null;
      }

      var block = {
        type: "a2ui",
        component: COMPONENT,
        id: genBlockId(context),
        state: "final",
        source: context.source || "system",
        confidence: 1,
        seq: context.seq != null ? Number(context.seq) : 0,
        turnId: context.turnId != null ? Number(context.turnId) : 1,
        traceId: context.traceId || "",
        props: { actions: actions }
      };

      if (root.PaletteBlockSchema && PaletteBlockSchema.sanitizeBlock) {
        var safe = PaletteBlockSchema.sanitizeBlock(block);
        if (!safe) {
          trace(context, "action_chips_empty", {
            cardId: context.cardId || "",
            reason: "schema_rejected"
          });
          return null;
        }
        block = safe;
      }

      trace(context, "action_chips_block_created", {
        cardId: context.cardId || "",
        blockId: block.id || "",
        component: COMPONENT,
        count: (block.props && block.props.actions ? block.props.actions.length : 0) || 0,
        invalidCount: normalized.invalidCount
      });
      return block;
    } catch (err) {
      trace(context, "action_chips_empty", {
        cardId: context.cardId || "",
        reason: "adapter_exception",
        error: String(err && err.message ? err.message : err)
      });
      return null;
    }
  }

  root.PaletteActionChipsAdapter = {
    COMPONENT: COMPONENT,
    normalizeFollowUpActionsToActionChips: normalizeFollowUpActionsToActionChips
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
