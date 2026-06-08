/**
 * PaletteA2UIEventBridge — Lit ActionChips a2ui-action → PaletteActionController
 *
 * actionSource: lit_component。legacy DOM click 走 PaletteActionBinder。
 */
(function (root) {
  var installed = false;
  var ACTION_SOURCE_LIT = "lit_component";

  function trace(options, event, payload) {
    if (!options || typeof options.debugLog !== "function") return;
    try {
      options.debugLog(event, typeof payload === "string" ? payload : JSON.stringify(payload));
    } catch (_) {}
  }

  function resolveCardId(target, action) {
    if (target && target.getAttribute) {
      var fromEl = target.getAttribute("card-id");
      if (fromEl) return String(fromEl);
    }
    if (action && action.cardId) return String(action.cardId);
    return "";
  }

  function buildContext(cardId, card, action, target, options) {
    options = options || {};
    return {
      cardId: cardId,
      card: card,
      chipId: action.id || "",
      chip: { id: action.id || "", label: action.label || "", kind: "safe" },
      dataSource: "action_chips_block",
      renderer: "lit",
      component: "ActionChips",
      slot: "ActionChips",
      actionSource: ACTION_SOURCE_LIT,
      debugLog: options.debugLog,
      onActionResult: options.onActionResult,
      submitFollowup:
        card && typeof card._submitFollowup === "function"
          ? card._submitFollowup
          : options.submitFollowup,
      resolveChips: function () {
        return Array.isArray(action._resolvedChips) ? action._resolvedChips : [action];
      }
    };
  }

  function install(options) {
    options = options || {};
    if (installed) return;
    if (typeof document === "undefined") return;
    installed = true;

    document.addEventListener("a2ui-action", function (e) {
      var action = (e && e.detail) || {};
      var target = e && e.target;
      try {
        trace(options, "action_chips_lit_event", {
          cardId: resolveCardId(target, action),
          actionId: action.id || "",
          intent: action.intent || "",
          actionSource: ACTION_SOURCE_LIT,
          renderer: "lit"
        });
        if (!root.PaletteActionController || !PaletteActionController.handleA2uiAction) {
          trace(options, "action_chips_lit_error", { reason: "controller_unavailable" });
          return;
        }
        var cardId = resolveCardId(target, action);
        if (!cardId) {
          trace(options, "action_chips_lit_error", { reason: "missing_card_id" });
          return;
        }
        var card = typeof options.getCard === "function" ? options.getCard(cardId) : null;
        if (!card) {
          trace(options, "action_chips_lit_error", { reason: "card_not_found", cardId: cardId });
          return;
        }
        PaletteActionController.handleA2uiAction(action, buildContext(cardId, card, action, target, options));
      } catch (err) {
        trace(options, "action_chips_lit_error", {
          cardId: resolveCardId(target, action),
          actionId: action.id || "",
          error: String(err && err.message ? err.message : err)
        });
      }
    });
  }

  function _resetForTest() {
    installed = false;
  }

  root.PaletteA2UIEventBridge = {
    install: install,
    _resetForTest: _resetForTest
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
