/**

 * PaletteActionController — A2UI action runtime（唯一新动作运行时，无 Lit 依赖）
 *
 * 所有 action intent 在此执行。PaletteActionBinder 仅作 legacy 桥接，不得新增 intent 分支。

 */

(function (root) {

  var SUPPORTED_INTENTS = ["prefill", "submit", "inspect", "apply", "undo", "route"];

  var NOOP_INTENTS = ["inspect", "route", "apply"];

  var ACTION_SOURCE_LIT = "lit_component";

  var ACTION_SOURCE_LEGACY = "legacy_bridge";



  var PREFILL_HINT_TEXT = "已从建议填入，可继续编辑后发送";

  var PREFILL_HINT_MS = 1900;



  function trace(context, event, payload) {

    if (!context || typeof context.debugLog !== "function") return;

    try {

      context.debugLog(event, typeof payload === "string" ? payload : JSON.stringify(payload));

    } catch (_) {}

  }



  function resolveActionSource(context) {

    context = context || {};

    if (context.actionSource) return String(context.actionSource);

    if (context.component === "ActionChips" && context.renderer === "lit") return ACTION_SOURCE_LIT;

    if (context.renderer === "lit") return ACTION_SOURCE_LIT;

    return ACTION_SOURCE_LEGACY;

  }



  function resolveIntent(raw) {

    var intent = String(raw != null ? raw : "").trim();

    if (SUPPORTED_INTENTS.indexOf(intent) >= 0) return intent;

    if (root.PaletteBlockSchema && PaletteBlockSchema.resolveActionChipIntent) {

      return PaletteBlockSchema.resolveActionChipIntent(intent);

    }

    if (intent === "append" || intent === "execute") {

      return intent === "execute" ? "submit" : "prefill";

    }

    return "prefill";

  }



  function resolvePayloadText(action) {

    action = action || {};

    var payload = action.payload && typeof action.payload === "object" ? action.payload : {};

    if (payload.text != null && String(payload.text).trim()) return String(payload.text).trim();

    if (action.text != null && String(action.text).trim()) return String(action.text).trim();

    if (action.prompt != null && String(action.prompt).trim()) return String(action.prompt).trim();

    if (action.prefill != null && String(action.prefill).trim()) return String(action.prefill).trim();

    if (action.label != null && String(action.label).trim()) return String(action.label).trim();

    return "";

  }



  function followupPlaceholderForUiState(uiState) {

    if (uiState === "Waiting") return "回答大脑提问后点发送…";

    if (uiState === "Done") return "追加新指令…";

    return "补充要求（不中断当前任务）…";

  }



  function resolveFollowupInput(cardId) {

    var dom = typeof document !== "undefined" ? document.getElementById("card-" + cardId) : null;

    return dom && dom.querySelector ? dom.querySelector(".card-followup-input") : null;

  }



  function clearPrefillHintInput(input) {

    if (!input || !input.dataset || input.dataset.prefillHint !== "1") return;

    var uiState = input.dataset.prefillUiState || "Done";

    delete input.dataset.prefillHint;

    delete input.dataset.prefillUiState;

    if (input._prefillHintTimer) {

      if (typeof clearTimeout === "function") clearTimeout(input._prefillHintTimer);

      input._prefillHintTimer = null;

    }

    if ("placeholder" in input) input.placeholder = followupPlaceholderForUiState(uiState);

  }



  function bindPrefillHintInput(input) {

    if (!input || input._prefillHintBound || !input.addEventListener) return;

    input._prefillHintBound = true;

    input.addEventListener("input", function () {

      if (input.dataset && input.dataset.prefillHint === "1") clearPrefillHintInput(input);

    });

  }



  function rememberPreviousInputValue(card, input) {

    if (!card || !input) return "";

    var previous = String(input.value != null ? input.value : "");

    card._prefillPreviousInputValue = previous;

    return previous;

  }



  function setCardPendingAction(card, actionId) {

    if (!card) return;

    card.pendingActionId = actionId ? String(actionId) : "";

  }



  function clearCardPendingAction(card) {

    if (!card) return;

    card.pendingActionId = "";

  }



  function queryActionChipsLitEl(dom) {
    if (!dom || !dom.querySelector) return null;
    if (root.PaletteActionBinder && PaletteActionBinder.queryActionChipsLitEl) {
      return PaletteActionBinder.queryActionChipsLitEl(dom);
    }
    var box = dom.querySelector(".card-followup-chips");
    if (box) {
      if (box.querySelector) {
        var nested = box.querySelector("palette-action-chips");
        if (nested) return nested;
      }
      if (box.children) {
        for (var i = 0; i < box.children.length; i++) {
          var child = box.children[i];
          if (
            child &&
            (child.tagName === "PALETTE-ACTION-CHIPS" || child.tagName === "palette-action-chips")
          ) {
            return child;
          }
        }
      }
    }
    return dom.querySelector("palette-action-chips");
  }

  function syncPendingToActionChipsDom(cardId, card) {

    if (typeof document === "undefined") return;

    var dom = document.getElementById("card-" + cardId);

    if (!dom || !dom.querySelector) return;

    var litEl = queryActionChipsLitEl(dom);

    if (litEl) litEl.pendingActionId = card && card.pendingActionId ? card.pendingActionId : "";

  }



  function applyPrefillToInput(cardId, value, card, context) {

    context = context || {};

    try {

      var input = resolveFollowupInput(cardId);

      if (!input) {

        trace(context, "a2ui_prefill_error", {

          cardId: cardId || "",

          reason: "input_missing"

        });

        return false;

      }

      rememberPreviousInputValue(card, input);

      input.value = value;

      if (input.dataset) {

        input.dataset.prefillHint = "1";

        input.dataset.prefillUiState = card && card.uiState ? String(card.uiState) : "Done";

      }

      if ("placeholder" in input) input.placeholder = PREFILL_HINT_TEXT;

      bindPrefillHintInput(input);

      if (typeof setTimeout === "function") {

        if (input._prefillHintTimer && typeof clearTimeout === "function") clearTimeout(input._prefillHintTimer);

        input._prefillHintTimer = setTimeout(function () {

          clearPrefillHintInput(input);

        }, PREFILL_HINT_MS);

      }

      if (input.classList && input.classList.add && typeof setTimeout === "function") {

        input.classList.add("is-prefilled");

        setTimeout(function () {

          if (input.classList && input.classList.remove) input.classList.remove("is-prefilled");

        }, 1800);

      }

      if (input.focus) input.focus();

      return true;

    } catch (err) {

      trace(context, "a2ui_prefill_error", {

        cardId: cardId || "",

        reason: "prefill_exception",

        error: String(err && err.message ? err.message : err)

      });

      return false;

    }

  }



  function buildResult(context, action, extra) {

    extra = extra || {};

    return Object.assign(

      {

        ok: extra.ok !== false,

        cardId: context.cardId || "",

        actionId: action.id || "",

        chipId: context.chipId || action.id || "",

        intent: action.intent || "prefill",

        label: action.label || "",

        dataSource: context.dataSource || "merged",

        renderer: context.renderer || "legacy",

        component: context.component || "follow-up-chips",

        slot: context.slot || "actions",

        actionSource: resolveActionSource(context)

      },

      extra

    );

  }



  function emitActionResult(result, context) {

    if (!context || typeof context.onActionResult !== "function") return;

    try {

      context.onActionResult(result);

    } catch (_) {}

  }



  function findChipForPolicy(action, context) {

    if (context.chip && context.chip.id) return context.chip;

    var chips =

      typeof context.resolveChips === "function" ? context.resolveChips() : [];

    for (var i = 0; i < chips.length; i++) {

      if (chips[i] && chips[i].id === action.id) return chips[i];

    }

    return {

      id: action.id || "",

      label: action.label || "",

      kind: "safe",

      prefill: resolvePayloadText(action)

    };

  }



  function evaluatePolicy(action, context) {

    if (!root.PaletteActionPolicy || !PaletteActionPolicy.evaluateChip) {

      return { allowed: true };

    }

    return PaletteActionPolicy.evaluateChip(findChipForPolicy(action, context), {

      card: context.card

    });

  }



  /**

   * 将 legacy palette-action detail 转为标准 A2UI action。

   */

  function legacyDetailToA2uiAction(detail, card, options) {

    detail = detail || {};

    options = options || {};

    card = card || {};

    var chip = detail.chip || {};

    var legacyAction = detail.action || {};

    var intent = "prefill";

    if (legacyAction.type === "submit") intent = "submit";

    else if (chip.intent === "execute" || detail.intent === "execute") intent = "submit";

    else if (chip.intent) intent = resolveIntent(chip.intent);

    else if (detail.intent) intent = resolveIntent(detail.intent);



    var text = "";

    if (legacyAction.value != null) text = String(legacyAction.value);

    else if (chip.prefill != null) text = String(chip.prefill);

    else if (chip.label != null) text = String(chip.label);



    if (intent === "prefill") {

      var resolved = [];

      if (options && typeof options.resolveChips === "function") {

        resolved = options.resolveChips();

      } else if (root.PaletteActionBinder && PaletteActionBinder.resolveFollowUpChips) {

        resolved = PaletteActionBinder.resolveFollowUpChips(card, options || {});

      }

      for (var i = 0; i < resolved.length; i++) {

        if (resolved[i] && resolved[i].id === (detail.chipId || chip.id)) {

          if (resolved[i].prefill) text = String(resolved[i].prefill);

          break;

        }

      }

    }



    return {

      id: String(detail.chipId || chip.id || ""),

      label: String(chip.label || chip.id || text || "").trim(),

      intent: intent,

      payload: { text: text },

      disabled: !!chip.disabled

    };

  }



  function handlePrefill(action, context) {

    var text = resolvePayloadText(action);

    var applied = applyPrefillToInput(context.cardId, text, context.card, context);

    if (!applied) {

      trace(context, "a2ui_prefill_error", {

        cardId: context.cardId || "",

        actionId: action.id || "",

        reason: "apply_failed"

      });

    }

    trace(context, "a2ui_action_prefill", {

      cardId: context.cardId || "",

      actionId: action.id || "",

      applied: applied,

      textPreview: String(text).slice(0, 80)

    });

    var result = buildResult(context, action, {

      ok: applied,

      actionType: "prefill",

      prefill: text,

      applied: applied,

      previousInputValue:

        context.card && context.card._prefillPreviousInputValue != null

          ? context.card._prefillPreviousInputValue

          : "",

      reason: applied ? "" : "apply_failed"

    });

    trace(context, "action_clicked", {

      id: result.chipId,

      label: result.label || String(text).slice(0, 40),

      intent: action.intent || "prefill",

      behavior: "prefill_only",

      actionType: "prefill",

      dataSource: result.dataSource,

      renderer: result.renderer,

      component: result.component,

      slot: result.slot,

      actionSource: resolveActionSource(context)

    });

    emitActionResult(result, context);

    return result;

  }



  function handleUndo(action, context) {

    var input = resolveFollowupInput(context.cardId);

    var previous =

      context.card && context.card._prefillPreviousInputValue != null

        ? String(context.card._prefillPreviousInputValue)

        : "";

    if (!input) {

      trace(context, "a2ui_action_error", {

        cardId: context.cardId || "",

        actionId: action.id || "",

        intent: "undo",

        reason: "input_missing"

      });

      return buildResult(context, action, { ok: false, actionType: "undo", reason: "input_missing" });

    }

    try {

      input.value = previous;

      clearPrefillHintInput(input);

      if (input.classList && input.classList.remove) input.classList.remove("is-prefilled");

      trace(context, "a2ui_action_undo", {

        cardId: context.cardId || "",

        actionId: action.id || "",

        restoredPreview: String(previous).slice(0, 80)

      });

      var undoResult = buildResult(context, action, {

        ok: true,

        actionType: "undo",

        restored: previous

      });

      emitActionResult(undoResult, context);

      return undoResult;

    } catch (err) {

      trace(context, "a2ui_action_error", {

        cardId: context.cardId || "",

        actionId: action.id || "",

        intent: "undo",

        error: String(err && err.message ? err.message : err)

      });

      return buildResult(context, action, { ok: false, actionType: "undo", reason: "undo_exception" });

    }

  }



  function handleSubmit(action, context) {

    var text = resolvePayloadText(action);

    setCardPendingAction(context.card, action.id);

    syncPendingToActionChipsDom(context.cardId, context.card);

    var submitted = false;

    try {

      if (text) applyPrefillToInput(context.cardId, text, context.card, context);

      if (typeof context.submitFollowup === "function") {

        submitted = context.submitFollowup(text) !== false;

      }

    } catch (err) {

      trace(context, "a2ui_action_error", {

        cardId: context.cardId || "",

        actionId: action.id || "",

        intent: "submit",

        error: String(err && err.message ? err.message : err)

      });

      return buildResult(context, action, { ok: false, actionType: "submit", reason: "submit_failed" });

    } finally {

      clearCardPendingAction(context.card);

      syncPendingToActionChipsDom(context.cardId, context.card);

    }

    trace(context, "a2ui_action_submit", {

      cardId: context.cardId || "",

      actionId: action.id || "",

      submitted: submitted,

      textPreview: String(text).slice(0, 80)

    });

    var result = buildResult(context, action, {

      ok: submitted,

      actionType: "submit",

      submitted: submitted,

      reason: submitted ? "" : "submit_handler_missing"

    });

    emitActionResult(result, context);

    return result;

  }



  function handleUnsupported(action, context) {

    trace(context, "a2ui_action_unsupported", {

      cardId: context.cardId || "",

      actionId: action.id || "",

      intent: action.intent || ""

    });

    return buildResult(context, action, {

      ok: true,

      handled: false,

      reason: "unsupported_intent"

    });

  }



  /**

   * @param {object} action 标准 A2UI action（id/label/intent/payload）

   * @param {object} context cardId/card/debugLog/onActionResult/submitFollowup/...

   */

  function handleA2uiAction(action, context) {

    context = context || {};

    action = action || {};

    try {

      var intent = resolveIntent(action.intent);

      action = Object.assign({}, action, { intent: intent });

      trace(context, "a2ui_action_received", {

        cardId: context.cardId || "",

        actionId: action.id || "",

        intent: intent,

        component: context.component || "",

        renderer: context.renderer || "",

        actionSource: resolveActionSource(context)

      });



      if (action.disabled) {

        trace(context, "a2ui_action_unsupported", {

          cardId: context.cardId || "",

          actionId: action.id || "",

          intent: intent,

          reason: "disabled"

        });

        return buildResult(context, action, { ok: false, reason: "disabled" });

      }



      if (!action.id && !action.label) {

        trace(context, "a2ui_action_error", {

          cardId: context.cardId || "",

          reason: "missing_action_identity"

        });

        return buildResult(context, action, { ok: false, reason: "invalid_action" });

      }



      var policy = evaluatePolicy(action, context);

      if (!policy.allowed) {

        trace(context, "action_rejected", {

          id: action.id || "",

          reason: policy.reason || "policy_rejected",

          phase: "controller",

          dataSource: context.dataSource || "",

          renderer: context.renderer || "",

          component: context.component || "",

          slot: context.slot || ""

        });

        return buildResult(context, action, { ok: false, reason: policy.reason || "policy_rejected" });

      }



      if (intent === "prefill") return handlePrefill(action, context);

      if (intent === "submit") return handleSubmit(action, context);

      if (intent === "undo") return handleUndo(action, context);

      if (NOOP_INTENTS.indexOf(intent) >= 0) return handleUnsupported(action, context);



      trace(context, "a2ui_action_unsupported", {

        cardId: context.cardId || "",

        actionId: action.id || "",

        intent: intent,

        reason: "unknown_intent"

      });

      return buildResult(context, action, { ok: true, handled: false, reason: "unknown_intent" });

    } catch (err) {

      trace(context, "a2ui_action_error", {

        cardId: context.cardId || "",

        actionId: action.id || "",

        error: String(err && err.message ? err.message : err)

      });

      return buildResult(context, action, { ok: false, reason: "controller_exception" });

    }

  }



  root.PaletteActionController = {

    SUPPORTED_INTENTS: SUPPORTED_INTENTS,

    ACTION_SOURCE_LIT: ACTION_SOURCE_LIT,

    ACTION_SOURCE_LEGACY: ACTION_SOURCE_LEGACY,

    resolveActionSource: resolveActionSource,

    PREFILL_HINT_TEXT: PREFILL_HINT_TEXT,

    PREFILL_HINT_MS: PREFILL_HINT_MS,

    legacyDetailToA2uiAction: legacyDetailToA2uiAction,

    handleA2uiAction: handleA2uiAction,

    applyPrefillToInput: applyPrefillToInput,

    resolvePayloadText: resolvePayloadText,

    clearPrefillHintInput: clearPrefillHintInput,

    bindPrefillHintInput: bindPrefillHintInput,

    setCardPendingAction: setCardPendingAction,

    clearCardPendingAction: clearCardPendingAction,

    syncPendingToActionChipsDom: syncPendingToActionChipsDom,

    resolveFollowupInput: resolveFollowupInput

  };

})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);

