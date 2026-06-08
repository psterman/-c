/**
 * PaletteActionChipsProdInjector — 生产路径将 reply.actions / followUpChips 注入 pipeline blocks
 */
(function (root) {
  var COMPONENT = "ActionChips";

  function trace(context, event, payload) {
    if (!context || typeof context.debugLog !== "function") return;
    try {
      context.debugLog(event, typeof payload === "string" ? payload : JSON.stringify(payload));
    } catch (_) {}
  }

  function isValidActionChipsBlock(block) {
    return !!(
      block &&
      block.type === "a2ui" &&
      String(block.component || "") === COMPONENT &&
      block.props &&
      Array.isArray(block.props.actions) &&
      block.props.actions.length
    );
  }

  function findExistingActionChips(blocks) {
    var list = Array.isArray(blocks) ? blocks : [];
    for (var i = 0; i < list.length; i++) {
      if (isValidActionChipsBlock(list[i])) return list[i];
    }
    return null;
  }

  function findLatestReplyBlock(blocks) {
    var list = Array.isArray(blocks) ? blocks : [];
    var best = null;
    var bestTurn = -1;
    for (var i = 0; i < list.length; i++) {
      var b = list[i];
      if (!b || b.type !== "reply") continue;
      var tid = b.turnId != null ? Number(b.turnId) : 1;
      if (tid >= bestTurn) {
        bestTurn = tid;
        best = b;
      }
    }
    return best;
  }

  function maxSeqForTurn(blocks, turnId) {
    var max = 0;
    var list = Array.isArray(blocks) ? blocks : [];
    for (var i = 0; i < list.length; i++) {
      var b = list[i];
      if (!b) continue;
      var tid = b.turnId != null ? Number(b.turnId) : 1;
      if (turnId != null && tid !== turnId) continue;
      if (b.seq != null && Number(b.seq) > max) max = Number(b.seq);
    }
    return max;
  }

  function buildInjectContext(blocks, context) {
    context = context || {};
    var card = context.card || null;
    var reply = findLatestReplyBlock(blocks);
    var turnId =
      context.turnId != null
        ? Number(context.turnId)
        : reply
          ? reply.turnId != null
            ? Number(reply.turnId)
            : 1
          : card && card._activeTurnId != null
            ? Number(card._activeTurnId)
            : 1;
    return {
      cardId: context.cardId || (card && card.id) || "",
      debugLog: context.debugLog,
      followUpChips:
        context.followUpChips ||
        (card && card.routeProfile && card.routeProfile.followUpChips) ||
        [],
      source: context.source || "system",
      traceId: context.traceId || (card && card.id ? String(card.id) + "_ac_prod" : ""),
      turnId: turnId,
      seq: maxSeqForTurn(blocks, turnId) + 1
    };
  }

  /**
   * @param {Array} blocks pipeline blocks
   * @param {object} context cardId, debugLog, followUpChips, card, turnId, traceId
   * @returns {{ blocks: Array, injected: boolean, skipped?: boolean, block?: object, error?: boolean }}
   */
  function injectActionChipsIntoPipelineBlocks(blocks, context) {
    var original = Array.isArray(blocks) ? blocks.slice() : [];
    var ctx = buildInjectContext(original, context);

    try {
      if (!root.PaletteActionChipsAdapter || !PaletteActionChipsAdapter.normalizeFollowUpActionsToActionChips) {
        trace(ctx, "action_chips_prod_adapter_error", {
          cardId: ctx.cardId,
          reason: "adapter_unavailable"
        });
        return { blocks: original, injected: false, error: true };
      }

      if (findExistingActionChips(original)) {
        trace(ctx, "action_chips_prod_skip_existing", { cardId: ctx.cardId });
        return { blocks: original, injected: false, skipped: true };
      }

      var reply = findLatestReplyBlock(original);
      var replyActions = reply && Array.isArray(reply.actions) ? reply.actions : [];
      if (!replyActions.length && !(ctx.followUpChips && ctx.followUpChips.length)) {
        return { blocks: original, injected: false };
      }

      var block = PaletteActionChipsAdapter.normalizeFollowUpActionsToActionChips(replyActions, ctx);
      if (!block) {
        return { blocks: original, injected: false };
      }

      var next = original.concat([block]);
      trace(ctx, "action_chips_prod_injected", {
        cardId: ctx.cardId,
        blockId: block.id || "",
        count: block.props && block.props.actions ? block.props.actions.length : 0,
        turnId: ctx.turnId,
        seq: block.seq
      });
      return { blocks: next, injected: true, block: block };
    } catch (err) {
      trace(ctx, "action_chips_prod_adapter_error", {
        cardId: ctx.cardId,
        error: String(err && err.message ? err.message : err)
      });
      return { blocks: original, injected: false, error: true };
    }
  }

  root.PaletteActionChipsProdInjector = {
    COMPONENT: COMPONENT,
    isValidActionChipsBlock: isValidActionChipsBlock,
    findExistingActionChips: findExistingActionChips,
    injectActionChipsIntoPipelineBlocks: injectActionChipsIntoPipelineBlocks
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
