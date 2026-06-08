/**
 * PaletteUIEventBridge — Lit palette-action 事件 → ActionController
 *
 * legacy DOM click 不经此 Bridge，由 PaletteActionBinder.bindFollowUpChips 处理。
 */
(function (root) {
  var installed = false;
  var ACTION_SOURCE_LIT = "lit_component";
  var ACTION_SOURCE_LEGACY = "legacy_bridge";

  function normalizeLitEntry(raw) {
    if (root.PaletteUIEventContract && PaletteUIEventContract.normalizePaletteAction) {
      return PaletteUIEventContract.normalizePaletteAction(raw);
    }
    return raw || {};
  }

  function buildControllerContext(cardId, card, detail, options) {
    options = options || {};
    detail = detail || {};
    var actionSource =
      detail.renderer === "lit" ? ACTION_SOURCE_LIT : ACTION_SOURCE_LEGACY;
    return {
      cardId: cardId,
      card: card,
      chipId: detail.chipId || "",
      chip: detail.chip || null,
      dataSource: detail.dataSource || "merged",
      renderer: detail.renderer || "legacy",
      component: detail.component || "follow-up-chips",
      slot: detail.slot || "actions",
      actionSource: actionSource,
      debugLog: options.debugLog,
      onActionResult: options.onActionResult,
      submitFollowup:
        card && typeof card._submitFollowup === "function"
          ? card._submitFollowup
          : options.submitFollowup,
      resolveChips: function () {
        if (root.PaletteActionBinder && PaletteActionBinder.resolveFollowUpChips) {
          return PaletteActionBinder.resolveFollowUpChips(card, options);
        }
        return [];
      }
    };
  }

  function install(options) {
    options = options || {};
    if (installed) return;
    if (typeof document === "undefined") return;
    installed = true;

    document.addEventListener("palette-action", function (e) {
      var raw = (e && e.detail) || {};
      var detail = normalizeLitEntry(raw);
      if (root.PaletteUIEventContract && PaletteUIEventContract.isValidPaletteAction) {
        if (!PaletteUIEventContract.isValidPaletteAction(detail)) {
          var reason =
            (PaletteUIEventContract.getRejectReason &&
              PaletteUIEventContract.getRejectReason(detail)) ||
            "invalid_action";
          if (options.debugLog) {
            try {
              options.debugLog(
                "action_rejected",
                JSON.stringify({
                  id: detail.chipId || "",
                  reason: reason,
                  phase: "bridge",
                  dataSource: detail.dataSource || "",
                  renderer: detail.renderer || "",
                  component: detail.component || "",
                  slot: detail.slot || "",
                  actionSource:
                    detail.renderer === "lit" ? ACTION_SOURCE_LIT : ACTION_SOURCE_LEGACY
                })
              );
            } catch (_) {}
          }
          return;
        }
      }

      var cardId = detail.cardId || "";
      if (!cardId) return;
      var card = typeof options.getCard === "function" ? options.getCard(cardId) : null;
      if (!card) return;
      if (!root.PaletteActionController || !PaletteActionController.handleA2uiAction) return;

      var a2uiAction = PaletteActionController.legacyDetailToA2uiAction(detail, card, {
        resolveChips: function () {
          if (root.PaletteActionBinder && PaletteActionBinder.resolveFollowUpChips) {
            return PaletteActionBinder.resolveFollowUpChips(card, options);
          }
          return [];
        }
      });
      PaletteActionController.handleA2uiAction(
        a2uiAction,
        buildControllerContext(cardId, card, detail, options)
      );
    });
  }

  root.PaletteUIEventBridge = {
    install: install,
    normalizeLitEntry: normalizeLitEntry
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
