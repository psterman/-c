/**
 * PaletteActionBinder — 动作策略层：FollowUpChips（v2，executeAction 唯一执行入口）
 */
(function (root) {
  var COMPONENT_ID = "follow-up-chips";
  var SLOT_ID = "actions";

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

  function resolveFollowUpChips(card, options) {
    options = options || {};
    card = card || {};
    var chips = [];
    var seen = {};
    var reply = getLatestReplyBlock(card);
    if (reply && Array.isArray(reply.actions) && reply.actions.length) {
      chips = chips.concat(reply.actions);
    }
    var rp = card.routeProfile || {};
    if (Array.isArray(rp.followUpChips) && rp.followUpChips.length) {
      chips = chips.concat(rp.followUpChips);
    }
    var merged = [];
    for (var i = 0; i < chips.length; i++) {
      var c = chips[i];
      if (!c || !c.id || seen[c.id]) continue;
      seen[c.id] = true;
      merged.push(c);
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

  function emitActionResult(result, options) {
    if (typeof options.onActionResult !== "function") return;
    try {
      options.onActionResult(result);
    } catch (_) {}
  }

  /** Legacy chip active 态；触发依据为 executeAction 统一 result，非 click 路径自行决定 */
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
            slot: detail.slot || SLOT_ID
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
      chipId: detail.chipId || ""
    };
  }

  function applyPrefillToInput(cardId, value) {
    var dom = typeof document !== "undefined" ? document.getElementById("card-" + cardId) : null;
    var input = dom && dom.querySelector ? dom.querySelector(".card-followup-input") : null;
    if (!input) return false;
    input.value = value;
    if (input.classList && input.classList.add) {
      input.classList.add("is-prefilled");
      setTimeout(function () {
        if (input.classList && input.classList.remove) input.classList.remove("is-prefilled");
      }, 1800);
    }
    if (input.focus) input.focus();
    return true;
  }

  /** 唯一 action 执行入口：input + debug + onActionResult（不含 toast/active DOM） */
  function executeAction(cardId, card, detail, options) {
    options = options || {};
    card = card || {};
    detail = detail || {};
    var action = detail.action;
    var chipId = detail.chipId || "";

    if (!action || action.type === "noop") {
      return rejectAction(detail, "noop_not_wired", options, "execute");
    }
    if (action.type === "submit") {
      return rejectAction(detail, "submit_not_wired", options, "execute");
    }
    if (action.type !== "prefill") {
      return rejectAction(detail, "invalid_action", options, "execute");
    }

    var prefill = String(action.value || "");
    var chips = resolveFollowUpChips(card, options);
    var chip = detail.chip || null;
    if (!chip || !chip.id) {
      for (var i = 0; i < chips.length; i++) {
        if (chips[i] && chips[i].id === chipId) {
          chip = chips[i];
          break;
        }
      }
    }
    if (!chip && chipId) {
      chip = { id: chipId, label: prefill, kind: "safe", prefill: prefill };
    }

    if (root.PaletteActionPolicy && PaletteActionPolicy.evaluateChip) {
      var ev = PaletteActionPolicy.evaluateChip(chip || { id: chipId, label: prefill, kind: "safe" }, {
        card: card
      });
      if (!ev.allowed) {
        return rejectAction(detail, ev.reason, options, "policy");
      }
      if (chip && chip.prefill) prefill = String(chip.prefill);
      else if (chip && chip.label && !prefill.trim()) prefill = String(chip.label);
      action = { type: "prefill", value: prefill };
    }

    applyPrefillToInput(cardId, prefill);

    var result = {
      ok: true,
      cardId: cardId,
      actionType: action.type,
      prefill: prefill,
      dataSource: detail.dataSource || "merged",
      renderer: detail.renderer || "legacy",
      component: detail.component || COMPONENT_ID,
      slot: detail.slot || SLOT_ID,
      chipId: chipId,
      label: chip && chip.label ? chip.label : String(prefill).slice(0, 40),
      intent: detail.intent || (chip && chip.intent) || "append"
    };

    if (options.debugLog) {
      try {
        options.debugLog(
          "action_clicked",
          JSON.stringify({
            id: chipId,
            label: result.label,
            intent: result.intent,
            behavior: "prefill_only",
            actionType: result.actionType,
            dataSource: result.dataSource,
            renderer: result.renderer,
            component: result.component,
            slot: result.slot
          })
        );
      } catch (_) {}
    }

    emitActionResult(result, options);
    return result;
  }

  function handleAction(cardId, card, detail, options) {
    options = options || {};
    detail = normalizeDetail(detail);
    if (root.PaletteUIEventContract && PaletteUIEventContract.isValidPaletteAction) {
      if (!PaletteUIEventContract.isValidPaletteAction(detail)) {
        var reason =
          PaletteUIEventContract.getRejectReason &&
          PaletteUIEventContract.getRejectReason(detail);
        return rejectAction(detail, reason || "invalid_action", options, "validate");
      }
    }
    return executeAction(cardId, card, detail, options);
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
    var reason = fallbackInfo && fallbackInfo.reason && fallbackInfo.reason !== "lit_ok" ? fallbackInfo.reason : "";
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
    var dom = typeof document !== "undefined" ? document.getElementById("card-" + cardId) : null;
    if (!dom) return { ok: false, count: 0, renderer: "none", reason: "bridge_unavailable" };
    var box = dom.querySelector(".card-followup-chips");
    if (!box) return { ok: false, count: 0, renderer: "none", reason: "bridge_unavailable" };
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
      var fallbackInfo = { reason: "lit_unavailable", detail: "" };
      if (litResult && litResult.reason) {
        fallbackInfo.reason = litResult.reason;
        fallbackInfo.detail = litResult.error || "";
      } else if (root.PaletteLitRenderer.explainLitFallback) {
        fallbackInfo = PaletteLitRenderer.explainLitFallback({ resultNull: true });
      }
      return renderLegacyFollowUpChips(cardId, card, box, chips, options, fallbackInfo);
    }

    return renderLegacyFollowUpChips(cardId, card, box, chips, options, {
      reason: "lit_unavailable",
      detail: ""
    });
  }

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
      handleAction(cardId, card, detail, options);
    });
  }

  root.PaletteActionBinder = {
    resolveFollowUpChips: resolveFollowUpChips,
    getLatestReplyBlock: getLatestReplyBlock,
    renderFollowUpChips: renderFollowUpChips,
    bindFollowUpChips: bindFollowUpChips,
    shouldShowChips: shouldShowChips,
    handleAction: handleAction,
    executeAction: executeAction,
    applyLegacyChipActive: applyLegacyChipActive
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
