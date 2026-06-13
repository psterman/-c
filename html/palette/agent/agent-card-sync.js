(function (global) {
  "use strict";
  var api = null;
  var CARD_SUMMARY_CACHE_KEY = "nmer_cp_card_summary_v1";
  function install(ctx) {
    api = ctx || null;
  }
  function buildCardSummaryCachePayload() {
    if (!api) return null;
    var ids = Object.keys(api.actionState.cards);
    if (!ids.length) return null;
    api.sortCardIds(ids);
    var out = [];
    for (var i = 0; i < ids.length && out.length < 20; i++) {
      var c = api.actionState.cards[ids[i]];
      if (!c) continue;
      out.push({
        cardId: c.id,
        id: c.id,
        uiState: c.uiState || "Done",
        title: c.title || c.query || "",
        query: c.query || "",
        rawAnswer: String(c._summaryPreview || c.rawAnswer || "").slice(0, 480),
        summaryOnly: true,
        ended: c.ended !== false,
        running: !!c.running,
        updatedAt: c.updatedAt || "",
        createdAt: c.createdAt || "",
        provider: c.provider || "",
        reqId: c.reqId || ""
      });
    }
    return out.length ? out : null;
  }
  function persistCardSummaryCache() {
    if (!api) return;
    if (!(api.state.paletteFlags && api.state.paletteFlags.stateStore)) return;
    try {
      var payload = buildCardSummaryCachePayload();
      if (payload) sessionStorage.setItem(CARD_SUMMARY_CACHE_KEY, JSON.stringify(payload));
    } catch (_) {}
  }
  function restoreCardSummaryCache() {
    if (!api) return false;
    try {
      var raw = sessionStorage.getItem(CARD_SUMMARY_CACHE_KEY);
      if (!raw) return false;
      var cards = JSON.parse(raw);
      if (!Array.isArray(cards) || !cards.length) return false;
      renderSync(cards, { summary: true, fromCache: true });
      return true;
    } catch (_) {
      return false;
    }
  }
  function finishActionCardSyncPaint(syncOpts) {
    if (!api) return;
    syncOpts = syncOpts || {};
    api.ensureActionResultsVisible();
    var paint = function () {
      api.renderActionHistoryList();
      api.syncActionResultsLayout();
      if (api.paletteDiscreteLayout() && typeof PaletteLayout !== "undefined") {
        api.scheduleDiscreteLayout(api.actionHasStoredCards());
      } else {
        api.syncWindowSize();
      }
      if (api.actionHasStoredCards() && !syncOpts.fromCache) {
        window.nmerPalette.setStatus(
          "已加载 " + Object.keys(api.actionState.cards).length + " 个历史任务",
          "success"
        );
      }
    };
    requestAnimationFrame(function () {
      requestAnimationFrame(paint);
    });
  }
  function renderSync(cards, syncOpts) {
    if (!api) return;
    syncOpts = syncOpts || {};
    cards = api.limitActionCardDtos(cards);
    var hostIds = {};
    for (var hi = 0; hi < cards.length; hi++) {
      var hid = String(cards[hi].cardId || cards[hi].id || "");
      if (hid) hostIds[hid] = true;
    }
    Object.keys(api.actionState.cards).forEach(function (id) {
      if (!hostIds[id] && id !== api.actionState._pendingCardId) api.removeActionCard(id, false);
    });
    api.beginActionCardBatchUpsert();
    try {
      for (var i = 0; i < cards.length; i++) {
        api.upsertActionCardFromDto(cards[i], { batch: true, summary: !!syncOpts.summary });
      }
    } finally {
      api.endActionCardBatchUpsert();
    }
    if (!cards.length && !api.actionHasStoredCards()) {
      api.clearActionHistoryLoading();
      api.renderActionHistoryList();
      return;
    }
    api.purgeActionEmptyHint();
    if (!api.actionState.activeCardId || !api.getActionCard(api.actionState.activeCardId)) {
      var pick = "";
      Object.keys(api.actionState.cards).forEach(function (cid) {
        if (!pick && api.isActionCardRunning(api.actionState.cards[cid])) pick = cid;
      });
      if (!pick) {
        var all = Object.keys(api.actionState.cards);
        api.sortCardIds(all);
        if (all.length) pick = all[0];
      }
      if (pick) {
        api.actionState.activeCardId = pick;
        if (api.isActionCardRunning(api.actionState.cards[pick])) api.actionState.cards[pick].expanded = true;
      }
    }
    if (Object.keys(api.actionState.cards).length === 1) {
      var sole = Object.keys(api.actionState.cards)[0];
      api.actionState.activeCardId = sole;
      api.actionState.cards[sole].expanded = api.isActionCardRunning(api.actionState.cards[sole]);
    }
    if (api.actionState.focusMode) api.collapseNonActiveCards();
    api.clearActionHistoryLoading();
    finishActionCardSyncPaint(syncOpts);
    if (!syncOpts.fromCache) {
      requestAnimationFrame(function () {
        persistCardSummaryCache();
      });
    }
    if (!syncOpts.fromCache) {
      setTimeout(api.scheduleAgentCardsRecover, syncOpts.summary ? 3500 : 1200);
    }
    requestAnimationFrame(api.replayExpandedCardPipelineBlocks);
  }
  function showActionIntentEmpty() {
    if (!api) return;
    var box = document.getElementById("results");
    if (!box) return;
    api.purgeActionEmptyHint();
    var hint = document.createElement("div");
    hint.className = "action-intent-empty";
    hint.textContent =
      "输入任务后 Enter 提交至 " +
      api.agentProviderLabel(api.state.agentProvider) +
      "；点「本地命令」可浏览 VK；Ctrl+Enter 执行选中命令";
    var stack = box.querySelector(".action-card-stack");
    if (stack) stack.appendChild(hint);
    else box.appendChild(hint);
    api.state.showResults = true;
    var panel = document.getElementById("palette-panel");
    if (panel) panel.classList.add("has-results");
    api.syncActionResultsLayout();
  }
  function showActionEmptyIfNeeded() {
    if (!api) return;
    if (api.actionHasStoredCards() || api.state.input.trim() || api.state.actionCmdBrowse) return;
    api.state.actions = [];
    api.state.showResults = true;
    api.clearActionCmdResultsDom();
    api.purgeActionEmptyHint();
    var box = document.getElementById("results");
    if (box && !box.querySelector(".action-card-stack")) {
      var stack = document.createElement("div");
      stack.className = "action-card-stack";
      box.appendChild(stack);
    }
    showActionIntentEmpty();
    var panel = document.getElementById("palette-panel");
    if (panel) panel.classList.add("has-results");
    api.syncWindowSize();
  }
  function requestSync() {
    if (!api) return;
    if (api.actionState._cardPullPending) return;
    if (api.paletteFastInput() && api.actionHasRunningCard()) return;
    api.actionState._cardPullPending = true;
    var finishPull = function () {
      api.actionState._cardPullPending = false;
    };
    var emptyFallbackTimer = setTimeout(function () {
      if (api.actionHasStoredCards()) return;
      finishPull();
      if (api.state.intent === "action" && !api.state.input.trim() && !api.state.actionCmdBrowse) {
        api.clearActionHistoryLoading();
        api.showActionEmptyIfNeeded();
      }
    }, 3600);
    api.actionState._cardPullEmptyTimer = emptyFallbackTimer;
    var pullFromAhk = function () {
      try {
        api.post({ type: "palette_agent_pull" });
      } catch (_) {}
      setTimeout(function () {
        finishPull();
        if (!api.actionHasStoredCards()) api.clearActionHistoryLoading();
      }, 1500);
    };
    if (api.paletteStateStoreShadowEnabled()) {
      var hubFallbackTimer = setTimeout(function () {
        if (!api.actionState._cardPullPending) return;
        pullFromAhk();
      }, 1200);
      api.fetchAgentSummaryFromHub(function (data) {
        clearTimeout(hubFallbackTimer);
        if (!api.actionState._cardPullPending) return;
        if (data && data.cards && data.cards.length > 0) {
          api.agentDebugLog(
            "hub_summary_pull",
            "n=" + data.cards.length + " seq=" + String(data.writeSeq || "")
          );
          clearTimeout(emptyFallbackTimer);
          renderSync(data.cards, { summary: true, source: "hub" });
          finishPull();
          return;
        }
        pullFromAhk();
      });
      return;
    }
    pullFromAhk();
  }
  global.PaletteAgentCardSync = {
    install: install,
    renderSync: renderSync,
    requestSync: requestSync,
    persistCardSummaryCache: persistCardSummaryCache,
    restoreCardSummaryCache: restoreCardSummaryCache,
    showActionEmptyIfNeeded: showActionEmptyIfNeeded
  };
})(typeof window !== "undefined" ? window : globalThis);
