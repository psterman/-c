/**

 * PaletteUIEventBridge — Lit palette-action 事件入口：normalize → Binder.handleAction

 * Legacy click 不经 Bridge，由 Binder.bindFollowUpChips 直接 handleAction（仍兜底 normalize+validate）

 */

(function (root) {

  var installed = false;



  function normalizeLitEntry(raw) {

    if (root.PaletteUIEventContract && PaletteUIEventContract.normalizePaletteAction) {

      return PaletteUIEventContract.normalizePaletteAction(raw);

    }

    return raw || {};

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

                  slot: detail.slot || ""

                })

              );

            } catch (_) {}

          }

          return;

        }

      }

      var cardId = detail.cardId || "";

      if (!cardId) return;

      var card = null;

      if (typeof options.getCard === "function") {

        card = options.getCard(cardId);

      }

      if (!card) return;

      if (!root.PaletteActionBinder || !PaletteActionBinder.handleAction) return;

      PaletteActionBinder.handleAction(cardId, card, detail, {

        debugLog: options.debugLog,

        onActionResult: options.onActionResult

      });

    });

  }



  root.PaletteUIEventBridge = {

    install: install,

    normalizeLitEntry: normalizeLitEntry

  };

})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);


