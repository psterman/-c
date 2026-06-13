(function (global) {
  "use strict";

  var MAX_DETAIL_DOM = 5;
  var lruOrder = [];

  function ensureCardDetailState(card) {
    if (!card) return;
    if (card.mountedDetail == null) card.mountedDetail = false;
  }

  function countMountedDetails(cards) {
    var n = 0;
    if (!cards) return 0;
    Object.keys(cards).forEach(function (id) {
      var c = cards[id];
      if (c && c.mountedDetail) n++;
    });
    return n;
  }

  function touchDetailLru(cardId) {
    cardId = String(cardId || "");
    if (!cardId) return;
    var i = lruOrder.indexOf(cardId);
    if (i >= 0) lruOrder.splice(i, 1);
    lruOrder.push(cardId);
  }

  function removeFromLru(cardId) {
    cardId = String(cardId || "");
    var i = lruOrder.indexOf(cardId);
    if (i >= 0) lruOrder.splice(i, 1);
  }

  function migrateActionCardDomStructure(el) {
    if (!el || el.querySelector(".card-summary-shell")) return;
    var summary = document.createElement("div");
    summary.className = "card-summary-shell";
    var detail = document.createElement("div");
    detail.className = "card-detail-pane";
    detail.hidden = true;

    var pulse = el.querySelector(".card-pulse-loader");
    var head = el.querySelector(".cmd-action-card-head");
    var compact = el.querySelector(".card-compact-progress");
    var live = el.querySelector(".card-live-thought");
    var body = el.querySelector(".card-body");
    var follow = el.querySelector(".card-followup");

    if (head) summary.appendChild(head);
    if (compact) summary.appendChild(compact);
    if (live) summary.appendChild(live);
    if (body) detail.appendChild(body);
    if (follow) detail.appendChild(follow);

    if (pulse && pulse.nextSibling) el.insertBefore(summary, pulse.nextSibling);
    else if (pulse) el.appendChild(summary);
    else el.insertBefore(summary, el.firstChild);
    el.appendChild(detail);
  }

  function getDetailPane(dom) {
    if (!dom) return null;
    migrateActionCardDomStructure(dom);
    return dom.querySelector(".card-detail-pane");
  }

  function stripPipelineBody(dom, cardId, api) {
    if (!dom) return;
    if (api && typeof api.clearOfficialA2ui === "function") {
      api.clearOfficialA2ui(cardId);
    }
    var selectors = [
      ".card-timeline",
      ".card-status-log",
      ".card-question",
      ".card-a2ui",
      ".card-replies"
    ];
    selectors.forEach(function (sel) {
      var node = dom.querySelector(sel);
      if (!node) return;
      node.innerHTML = "";
      if (node.hidden !== undefined) node.hidden = true;
    });
    var official = dom.querySelector(".card-official-a2ui");
    if (official) {
      var mount = official.querySelector(".card-official-a2ui-mount");
      if (mount) mount.innerHTML = "";
      official.hidden = true;
    }
    dom.classList.remove("has-status-log");
    var card = api && api.getActionCard ? api.getActionCard(cardId) : null;
    if (card) card._pipelineDomEvicted = true;
  }

  function setDetailPaneVisible(dom, card, visible) {
    if (!dom || !card) return;
    migrateActionCardDomStructure(dom);
    var pane = dom.querySelector(".card-detail-pane");
    if (!pane) return;
    pane.hidden = !visible;
    dom.classList.toggle("mounted-detail", !!visible);
    if (visible) card.mountedDetail = true;
    else card.mountedDetail = false;
  }

  function unloadCardDetail(cardId, api) {
    if (!api) return { ok: false };
    cardId = String(cardId || "");
    var card = api.getActionCard(cardId);
    if (!card) return { ok: false, reason: "card_not_found" };
    var dom = document.getElementById("card-" + cardId);
    if (dom) {
      stripPipelineBody(dom, cardId, api);
      setDetailPaneVisible(dom, card, false);
    }
    card.mountedDetail = false;
    card._pipelineDomEvicted = true;
    if (api.actionState.detailCardId === cardId) {
      card.expanded = false;
    }
    removeFromLru(cardId);
    return { ok: true, cardId: cardId };
  }

  function evictLruDetailDom(exceptId, api) {
    exceptId = String(exceptId || "");
    if (!api || !api.actionState) return;
    var cards = api.actionState.cards || {};
    while (countMountedDetails(cards) >= MAX_DETAIL_DOM) {
      var victim = null;
      for (var i = 0; i < lruOrder.length; i++) {
        var cid = lruOrder[i];
        if (cid === exceptId) continue;
        var c = cards[cid];
        if (c && c.mountedDetail) {
          victim = cid;
          break;
        }
      }
      if (!victim) {
        Object.keys(cards).some(function (id) {
          if (id === exceptId) return false;
          if (cards[id] && cards[id].mountedDetail) {
            victim = id;
            return true;
          }
          return false;
        });
      }
      if (!victim) break;
      unloadCardDetail(victim, api);
    }
  }

  function mountCardDetail(cardId, api) {
    if (!api) return { ok: false };
    cardId = String(cardId || "");
    var card = api.getActionCard(cardId);
    if (!card) return { ok: false, reason: "card_not_found" };
    ensureCardDetailState(card);
    evictLruDetailDom(cardId, api);
    var dom = api.ensureActionCardDom(card);
    if (!dom) return { ok: false, reason: "dom_unavailable" };
    migrateActionCardDomStructure(dom);
    card.mountedDetail = true;
    card._pipelineDomEvicted = false;
    card.expanded = true;
    setDetailPaneVisible(dom, card, true);
    touchDetailLru(cardId);
    if (typeof api.ensureCardPipelineRendered === "function") {
      api.ensureCardPipelineRendered(card);
    }
    if (typeof api.refreshActionCardDom === "function") {
      api.refreshActionCardDom(card);
    }
    return { ok: true, cardId: cardId };
  }

  function replayMountedDetailPipelines(api) {
    if (!api || !api.actionState) return;
    var cards = api.actionState.cards || {};
    Object.keys(cards).forEach(function (cid) {
      var c = cards[cid];
      if (c && c.mountedDetail && typeof api.ensureCardPipelineRendered === "function") {
        api.ensureCardPipelineRendered(c);
      }
    });
  }

  global.PaletteDetailDomLru = {
    MAX_DETAIL_DOM: MAX_DETAIL_DOM,
    ensureCardDetailState: ensureCardDetailState,
    migrateActionCardDomStructure: migrateActionCardDomStructure,
    mountCardDetail: mountCardDetail,
    unloadCardDetail: unloadCardDetail,
    evictLruDetailDom: evictLruDetailDom,
    stripPipelineBody: stripPipelineBody,
    replayMountedDetailPipelines: replayMountedDetailPipelines,
    countMountedDetails: countMountedDetails
  };
})(typeof window !== "undefined" ? window : globalThis);
