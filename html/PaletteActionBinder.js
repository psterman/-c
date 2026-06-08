/**
 * PaletteActionBinder — legacy compatibility layer
 *
 * 职责（仅此，勿在此新增 intent 分支）：
 * - legacy DOM 渲染 fallback（.card-followup-chips 按钮 HTML）
 * - legacy DOM click 桥接（bindFollowUpChips）
 * - FollowUpChips 数据合并（resolveFollowUpChips，供 legacy/Lit 渲染读取）
 *
 * 动作语义全部委托 PaletteActionController（A2UI action runtime，唯一新动作运行时）。
 */
(function (root) {
  var COMPONENT_ID = "follow-up-chips";
  var SLOT_ID = "actions";
  var ACTION_SOURCE_LEGACY = "legacy_bridge";
  var ACTION_CHIPS_COMPONENT = "ActionChips";

  function getCardPipelineBlocks(card) {
    return (card && card.blockStore && card.blockStore.blocks) || (card && card.pipelineBlocks) || [];
  }

  function isValidActionChipsBlock(block) {
    return !!(
      block &&
      block.type === "a2ui" &&
      String(block.component || "") === ACTION_CHIPS_COMPONENT &&
      block.props &&
      Array.isArray(block.props.actions) &&
      block.props.actions.length
    );
  }

  function findValidActionChipsBlock(card) {
    var blocks = getCardPipelineBlocks(card);
    for (var i = 0; i < blocks.length; i++) {
      if (isValidActionChipsBlock(blocks[i])) return blocks[i];
    }
    return null;
  }

  function actionChipDedupeKey(chip) {
    chip = chip || {};
    if (chip.id) return "id:" + String(chip.id);
    var label = String(chip.label != null ? chip.label : "").trim();
    var intent = String(chip.intent != null ? chip.intent : "prefill").trim();
    var text = "";
    if (chip.payload && chip.payload.text != null) text = String(chip.payload.text).trim();
    else if (chip.prefill != null) text = String(chip.prefill).trim();
    return "sig:" + label + "|" + intent + "|" + text;
  }

  function logLegacyActionsEvent(options, event, payload) {
    if (!options || !options.debugLog) return;
    try {
      options.debugLog(event, typeof payload === "string" ? payload : JSON.stringify(payload));
    } catch (_) {}
  }

  function queryActionChipsLitEl(dom) {
    if (!dom || !dom.querySelector) return null;
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

  function countLitActionChipsDom(dom) {
    var litEl = queryActionChipsLitEl(dom);
    if (!litEl) return 0;
    if (litEl.actions && litEl.actions.length) return litEl.actions.length;
    return 1;
  }

  function evaluateLegacyFollowUpRender(card, dom) {
    var validBlock = findValidActionChipsBlock(card);
    var litEl = queryActionChipsLitEl(dom);

    if (!validBlock) {
      return {
        mode: "render",
        trace: "legacy_actions_rendered_no_action_chips",
        reason: "no_valid_action_chips_block"
      };
    }

    if (card && card._actionChipsLitRendered) {
      return {
        mode: "skip",
        trace: "legacy_actions_skipped_by_action_chips",
        reason: "action_chips_lit_flag",
        count: countLitActionChipsDom(dom)
      };
    }

    if (litEl && litEl.actions && litEl.actions.length) {
      return {
        mode: "skip",
        trace: "legacy_actions_skipped_by_action_chips",
        reason: "action_chips_lit_active",
        count: litEl.actions.length
      };
    }

    if (card && card._actionChipsPipelineHandled) {
      return {
        mode: "fallback",
        trace: "legacy_actions_rendered_as_fallback",
        reason: "action_chips_pipeline_lit_failed"
      };
    }

    return {
      mode: "skip",
      trace: "legacy_actions_skipped_by_action_chips",
      reason: "action_chips_block_pending_pipeline"
    };
  }

  function getLatestReplyBlock(card) {
    var blocks =
      (card && card.blockStore && card.blockStore.blocks) ||
      (card && card.pipelineBlocks) ||
      [];
    var best = null;
    var bestTurn = -1;
    for (var i = 0; i < blocks.length; i++) {
      var b = blocks[i];
      if (!b || b.type !== "reply") continue;
      var tid = b.turnId != null ? Number(b.turnId) : 1;
      if (tid >= bestTurn) {
        bestTurn = tid;
        best = b;
      }
    }
    return best;
  }

  function mapPipelineActionChipToLegacy(chip) {
    chip = chip || {};
    var text =
      chip.payload && chip.payload.text != null
        ? String(chip.payload.text)
        : chip.label != null
          ? String(chip.label)
          : "";
    return {
      id: chip.id || "",
      label: chip.label || chip.id || "",
      kind: "safe",
      intent: chip.intent || "prefill",
      prefill: text,
      disabled: !!chip.disabled
    };
  }

  function getPipelineActionChips(card) {
    var blocks = getCardPipelineBlocks(card);
    var out = [];
    for (var i = 0; i < blocks.length; i++) {
      var b = blocks[i];
      if (!isValidActionChipsBlock(b)) continue;
      var acts = b.props.actions;
      for (var j = 0; j < acts.length; j++) {
        var mapped = mapPipelineActionChipToLegacy(acts[j]);
        if (mapped.id || mapped.label) out.push(mapped);
      }
    }
    return out;
  }

  function resolveFollowUpChips(card, options) {
    options = options || {};
    card = card || {};
    var chips = [];
    var dedupedCount = 0;
    var validBlock = findValidActionChipsBlock(card);
    var primaryKeys = {};

    var pipeline = getPipelineActionChips(card);
    if (pipeline.length) {
      for (var pi = 0; pi < pipeline.length; pi++) {
        chips.push(pipeline[pi]);
        primaryKeys[actionChipDedupeKey(pipeline[pi])] = true;
      }
    }

    if (!validBlock) {
      var reply = getLatestReplyBlock(card);
      if (reply && Array.isArray(reply.actions) && reply.actions.length) {
        chips = chips.concat(reply.actions);
      }
    } else {
      var replyBlock = getLatestReplyBlock(card);
      if (replyBlock && Array.isArray(replyBlock.actions)) {
        for (var rai = 0; rai < replyBlock.actions.length; rai++) {
          if (primaryKeys[actionChipDedupeKey(replyBlock.actions[rai])]) dedupedCount++;
        }
      }
    }

    var rp = card.routeProfile || {};
    if (Array.isArray(rp.followUpChips) && rp.followUpChips.length) {
      for (var fi = 0; fi < rp.followUpChips.length; fi++) {
        var fc = rp.followUpChips[fi];
        if (!fc) continue;
        if (primaryKeys[actionChipDedupeKey(fc)]) {
          dedupedCount++;
          continue;
        }
        chips.push(fc);
      }
    }

    var merged = [];
    var mergeSeen = {};
    for (var i = 0; i < chips.length; i++) {
      var c = chips[i];
      if (!c) continue;
      var dk = actionChipDedupeKey(c);
      if (mergeSeen[dk]) {
        dedupedCount++;
        continue;
      }
      mergeSeen[dk] = true;
      merged.push(c);
    }

    if (dedupedCount > 0) {
      logLegacyActionsEvent(options, "legacy_actions_deduped", {
        cardId: (card && card.id) || "",
        dedupedCount: dedupedCount,
        outputCount: merged.length,
        hasValidActionChipsBlock: !!validBlock
      });
    }

    if (root.PaletteActionPolicy && PaletteActionPolicy.filterSafeActions) {
      return PaletteActionPolicy.filterSafeActions(merged, {
        debugLog: options.debugLog,
        card: card
      });
    }
    return merged;
  }

  function shouldShowChips(card) {
    if (!card || !card.expanded) return false;
    return card.uiState === "Done" || card.uiState === "Waiting";
  }

  function normalizeDetail(detail) {
    if (root.PaletteUIEventContract && PaletteUIEventContract.normalizePaletteAction) {
      return PaletteUIEventContract.normalizePaletteAction(detail);
    }
    return detail || {};
  }

  function logFallback(cardId, card, options, reason, detail) {
    if (!options.debugLog) return;
    try {
      options.debugLog(
        "followup_chips_fallback",
        JSON.stringify({
          cardId: cardId,
          routeId: (card.routeProfile && card.routeProfile.routeId) || card.routeId || "",
          reason: reason,
          detail: detail || "",
          at: Date.now(),
          renderer: "legacy",
          component: COMPONENT_ID,
          slot: SLOT_ID,
          actionSource: ACTION_SOURCE_LEGACY,
          available: false
        })
      );
    } catch (_) {}
  }

  function logChipsRender(cardId, card, payload, options) {
    if (!options.debugLog) return;
    try {
      options.debugLog("followup_chips_render", JSON.stringify(payload));
    } catch (_) {}
  }

  /** Legacy chip active 态；由 ActionController result 触发，非 Binder 自行决定 */
  function applyLegacyChipActive(cardId, chipId) {
    if (!chipId) return;
    var dom = typeof document !== "undefined" ? document.getElementById("card-" + cardId) : null;
    if (!dom) return;
    var box = dom.querySelector(".card-followup-chips");
    if (!box || box.querySelector("palette-followup-chips")) return;
    var chips = box.querySelectorAll(".card-followup-chip");
    for (var i = 0; i < chips.length; i++) chips[i].classList.remove("is-active");
    var sel =
      '.card-followup-chip[data-chip-id="' + String(chipId).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"]';
    var btn = box.querySelector(sel);
    if (!btn) return;
    btn.classList.add("is-active");
    setTimeout(function () {
      btn.classList.remove("is-active");
    }, 200);
  }

  function rejectAction(detail, reason, options, phase) {
    if (options.debugLog) {
      try {
        options.debugLog(
          "action_rejected",
          JSON.stringify({
            id: detail.chipId || "",
            reason: reason,
            phase: phase || "click",
            dataSource: detail.dataSource || "",
            renderer: detail.renderer || "legacy",
            component: detail.component || COMPONENT_ID,
            slot: detail.slot || SLOT_ID,
            actionSource: ACTION_SOURCE_LEGACY
          })
        );
      } catch (_) {}
    }
    return {
      ok: false,
      reason: reason,
      dataSource: detail.dataSource || "",
      renderer: detail.renderer || "legacy",
      component: detail.component || COMPONENT_ID,
      slot: detail.slot || SLOT_ID,
      chipId: detail.chipId || "",
      actionSource: ACTION_SOURCE_LEGACY
    };
  }

  function validateLegacyPaletteAction(detail, options) {
    if (!root.PaletteUIEventContract || !PaletteUIEventContract.isValidPaletteAction) {
      return { ok: true };
    }
    if (PaletteUIEventContract.isValidPaletteAction(detail)) {
      return { ok: true };
    }
    var reason =
      PaletteUIEventContract.getRejectReason && PaletteUIEventContract.getRejectReason(detail);
    return { ok: false, reason: reason || "invalid_action" };
  }

  function buildControllerContext(cardId, card, detail, options) {
    options = options || {};
    detail = detail || {};
    return {
      cardId: cardId,
      card: card,
      chipId: detail.chipId || "",
      chip: detail.chip || null,
      dataSource: detail.dataSource || "merged",
      renderer: detail.renderer || "legacy",
      component: detail.component || COMPONENT_ID,
      slot: detail.slot || SLOT_ID,
      actionSource: options.actionSource || ACTION_SOURCE_LEGACY,
      debugLog: options.debugLog,
      onActionResult: options.onActionResult,
      submitFollowup: options.submitFollowup,
      resolveChips: function () {
        return resolveFollowUpChips(card, options);
      }
    };
  }

  /**
   * legacy palette-action detail → ActionController（Binder 不执行 intent）
   */
  function bridgeLegacyActionToController(cardId, card, detail, options) {
    options = options || {};
    card = card || {};
    detail = detail || {};
    if (!root.PaletteActionController || !PaletteActionController.handleA2uiAction) {
      return rejectAction(detail, "controller_unavailable", options, "bridge");
    }
    var a2uiAction = PaletteActionController.legacyDetailToA2uiAction(detail, card, {
      resolveChips: function () {
        return resolveFollowUpChips(card, options);
      }
    });
    if (options.debugLog) {
      try {
        options.debugLog(
          "legacy_action_bridge",
          JSON.stringify({
            cardId: cardId,
            chipId: detail.chipId || "",
            intent: a2uiAction.intent || "",
            renderer: detail.renderer || "legacy",
            actionSource: options.actionSource || ACTION_SOURCE_LEGACY
          })
        );
      } catch (_) {}
    }
    return PaletteActionController.handleA2uiAction(
      a2uiAction,
      buildControllerContext(cardId, card, detail, options)
    );
  }

  /** @deprecated 使用 bridgeLegacyActionToController；保留别名兼容旧调用 */
  function executeAction(cardId, card, detail, options) {
    return bridgeLegacyActionToController(cardId, card, detail, options);
  }

  /**
   * legacy DOM / palette-action 统一入口：校验契约后桥接到 ActionController
   */
  function handleAction(cardId, card, detail, options) {
    options = options || {};
    detail = normalizeDetail(detail);
    var validation = validateLegacyPaletteAction(detail, options);
    if (!validation.ok) {
      return rejectAction(detail, validation.reason, options, "validate");
    }
    return bridgeLegacyActionToController(
      cardId,
      card,
      detail,
      Object.assign({ actionSource: ACTION_SOURCE_LEGACY }, options)
    );
  }

  function renderLegacyFollowUpChips(cardId, card, box, chips, options, fallbackInfo) {
    box.hidden = false;
    box.innerHTML = chips
      .map(function (c) {
        var val = String(c.prefill || c.label || "");
        return (
          '<button type="button" class="card-followup-chip" data-chip-id="' +
          String(c.id || "").replace(/"/g, "") +
          '" data-prefill="' +
          val.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;") +
          '">' +
          String(c.label || c.id || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;") +
          "</button>"
        );
      })
      .join("");
    var reason = fallbackInfo && fallbackInfo.reason && fallbackInfo.reason !== "ok" ? fallbackInfo.reason : "";
    if (reason) logFallback(cardId, card, options, reason, fallbackInfo.detail);
    logChipsRender(
      cardId,
      card,
      {
        cardId: cardId,
        routeId: (card.routeProfile && card.routeProfile.routeId) || card.routeId || "",
        chipIds: chips.map(function (c) {
          return c.id;
        }),
        count: chips.length,
        renderer: "legacy",
        component: COMPONENT_ID,
        slot: SLOT_ID,
        actionSource: ACTION_SOURCE_LEGACY,
        fallbackReason: reason
      },
      options
    );
    return {
      ok: true,
      count: chips.length,
      chips: chips,
      renderer: "legacy",
      component: COMPONENT_ID,
      slot: SLOT_ID,
      reason: reason
    };
  }

  function renderFollowUpChips(cardId, card, options) {
    options = options || {};
    card = card || {};
    var dom =
      options.dom ||
      (typeof document !== "undefined" ? document.getElementById("card-" + cardId) : null);
    if (!dom) return { ok: false, count: 0, renderer: "none", reason: "bridge_unavailable" };
    var box = dom.querySelector(".card-followup-chips");
    if (!box) return { ok: false, count: 0, renderer: "none", reason: "bridge_unavailable" };

    var decision = options.legacyRenderDecision || evaluateLegacyFollowUpRender(card, dom);
    if (decision.mode === "skip") {
      logLegacyActionsEvent(options, decision.trace || "legacy_actions_skipped_by_action_chips", {
        cardId: cardId,
        reason: decision.reason || "",
        count: decision.count != null ? decision.count : countLitActionChipsDom(dom)
      });
      if (queryActionChipsLitEl(dom)) box.hidden = false;
      return {
        ok: true,
        count: decision.count != null ? decision.count : countLitActionChipsDom(dom),
        renderer: "skipped",
        reason: decision.reason || "skipped_by_action_chips",
        skippedByActionChips: true
      };
    }

    if (decision.mode === "fallback") {
      logLegacyActionsEvent(options, decision.trace || "legacy_actions_rendered_as_fallback", {
        cardId: cardId,
        reason: decision.reason || ""
      });
    } else {
      logLegacyActionsEvent(options, decision.trace || "legacy_actions_rendered_no_action_chips", {
        cardId: cardId,
        reason: decision.reason || ""
      });
    }

    var chips = resolveFollowUpChips(card, options);

    if (!shouldShowChips(card) || !chips.length) {
      box.hidden = true;
      box.innerHTML = "";
      logChipsRender(
        cardId,
        card,
        {
          cardId: cardId,
          count: 0,
          renderer: "none",
          component: COMPONENT_ID,
          slot: SLOT_ID,
          reason: "empty_chips"
        },
        options
      );
      return { ok: true, count: 0, renderer: "none", reason: "empty_chips" };
    }

    if (root.PaletteLitRenderer && PaletteLitRenderer.renderFollowUpChips) {
      var litResult = PaletteLitRenderer.renderFollowUpChips(cardId, card, box, options);
      if (litResult && litResult.ok && litResult.renderer === "lit") return litResult;
      var fallbackInfo = { reason: "no_lit_component", detail: "" };
      if (litResult && litResult.reason) {
        fallbackInfo.reason = litResult.reason;
        fallbackInfo.detail = litResult.error || "";
      } else if (root.PaletteLitRenderer.explainLitFallback) {
        fallbackInfo = PaletteLitRenderer.explainLitFallback({ resultNull: true });
      }
      return renderLegacyFollowUpChips(cardId, card, box, chips, options, fallbackInfo);
    }

    return renderLegacyFollowUpChips(cardId, card, box, chips, options, {
      reason: "no_lit_component",
      detail: ""
    });
  }

  /** legacy .card-followup-chip DOM click → handleAction → ActionController */
  function bindFollowUpChips(cardId, card, options) {
    options = options || {};
    var dom = typeof document !== "undefined" ? document.getElementById("card-" + cardId) : null;
    if (!dom) return;
    if (dom._followUpChipsBound) return;
    dom._followUpChipsBound = true;
    dom.addEventListener("click", function (e) {
      var btn = e.target && e.target.closest ? e.target.closest(".card-followup-chip") : null;
      if (!btn || !dom.contains(btn)) return;
      if (btn.closest && btn.closest("palette-followup-chips")) return;
      if (btn.closest && btn.closest("palette-action-chips")) return;
      e.stopPropagation();
      if (!root.PaletteUIEventContract || !PaletteUIEventContract.buildChipClickDetail) return;
      var chipId = btn.getAttribute("data-chip-id") || "";
      var prefill = btn.getAttribute("data-prefill") || btn.textContent || "";
      var detail = PaletteUIEventContract.buildChipClickDetail({
        cardId: cardId,
        chipId: chipId,
        chip: { id: chipId, label: prefill.trim(), kind: "safe" },
        action: { type: "prefill", value: prefill },
        dataSource: "merged",
        renderer: "legacy"
      });
      handleAction(
        cardId,
        card,
        detail,
        Object.assign({ actionSource: ACTION_SOURCE_LEGACY }, options)
      );
    });
  }

  /** @deprecated 请使用 PaletteActionController.applyPrefillToInput */
  function applyPrefillToInput(cardId, value, card) {
    if (root.PaletteActionController && PaletteActionController.applyPrefillToInput) {
      return PaletteActionController.applyPrefillToInput(cardId, value, card);
    }
    return false;
  }

  root.PaletteActionBinder = {
    ACTION_SOURCE_LEGACY: ACTION_SOURCE_LEGACY,
    ACTION_CHIPS_COMPONENT: ACTION_CHIPS_COMPONENT,
    isValidActionChipsBlock: isValidActionChipsBlock,
    findValidActionChipsBlock: findValidActionChipsBlock,
    actionChipDedupeKey: actionChipDedupeKey,
    evaluateLegacyFollowUpRender: evaluateLegacyFollowUpRender,
    queryActionChipsLitEl: queryActionChipsLitEl,
    logLegacyActionsEvent: logLegacyActionsEvent,
    resolveFollowUpChips: resolveFollowUpChips,
    getPipelineActionChips: getPipelineActionChips,
    getLatestReplyBlock: getLatestReplyBlock,
    renderFollowUpChips: renderFollowUpChips,
    bindFollowUpChips: bindFollowUpChips,
    shouldShowChips: shouldShowChips,
    handleAction: handleAction,
    bridgeLegacyActionToController: bridgeLegacyActionToController,
    executeAction: executeAction,
    applyPrefillToInput: applyPrefillToInput,
    applyLegacyChipActive: applyLegacyChipActive
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
