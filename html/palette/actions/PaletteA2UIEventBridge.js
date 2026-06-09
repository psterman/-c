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
    if (action && action.cardId) return String(action.cardId);
    if (target && target.getAttribute) {
      var fromEl = target.getAttribute("card-id");
      if (fromEl) return String(fromEl);
    }
    return "";
  }

  function resolveBlockId(target, envelope) {
    if (envelope && envelope.blockId) return String(envelope.blockId);
    if (target && target.getAttribute) {
      var fromEl = target.getAttribute("block-id");
      if (fromEl) return String(fromEl);
    }
    return "";
  }

  function normalizeEventDetail(detail) {
    detail = detail || {};
    if (detail.action && typeof detail.action === "object") {
      return {
        version: Number(detail.version || 1),
        eventId: String(detail.eventId || ""),
        timestamp: Number(detail.timestamp || Date.now()),
        cardId: String(detail.cardId || ""),
        blockId: String(detail.blockId || ""),
        action: detail.action,
        state: detail.state && typeof detail.state === "object" ? detail.state : {}
      };
    }
    return {
      version: 0,
      eventId: "",
      timestamp: Date.now(),
      cardId: String(detail.cardId || ""),
      blockId: String(detail.blockId || ""),
      action: detail,
      state: {}
    };
  }

  function buildContext(cardId, card, envelope, target, options) {
    options = options || {};
    var action = envelope.action || {};
    return {
      cardId: cardId,
      blockId: resolveBlockId(target, envelope),
      eventId: envelope.eventId || "",
      eventTimestamp: envelope.timestamp || 0,
      eventState: envelope.state || {},
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
      var envelope = normalizeEventDetail((e && e.detail) || {});
      var action = envelope.action || {};
      var target = e && e.target;
      try {
        trace(options, "action_chips_lit_event", {
          eventId: envelope.eventId || "",
          cardId: resolveCardId(target, envelope),
          blockId: resolveBlockId(target, envelope),
          actionId: action.id || "",
          intent: action.intent || "",
          actionSource: ACTION_SOURCE_LIT,
          renderer: "lit"
        });
        if (!root.PaletteActionController || !PaletteActionController.handleA2uiAction) {
          trace(options, "action_chips_lit_error", { reason: "controller_unavailable" });
          return;
        }
        var cardId = resolveCardId(target, envelope);
        if (!cardId) {
          trace(options, "action_chips_lit_error", { reason: "missing_card_id" });
          return;
        }
        var card = typeof options.getCard === "function" ? options.getCard(cardId) : null;
        if (!card) {
          trace(options, "action_chips_lit_error", { reason: "card_not_found", cardId: cardId });
          return;
        }
        PaletteActionController.handleA2uiAction(
          action,
          buildContext(cardId, card, envelope, target, options)
        );
      } catch (err) {
        trace(options, "action_chips_lit_error", {
          cardId: resolveCardId(target, envelope),
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
    normalizeEventDetail: normalizeEventDetail,
    _resetForTest: _resetForTest
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
