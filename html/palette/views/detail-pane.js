(function (global) {
  "use strict";

  var _ctx = null;

  function install(ctx) {
    _ctx = ctx || {};
  }

  function sectionTarget(dom, section) {
    if (!dom) return null;
    if (section === "structure") return dom.querySelector(".card-a2ui:not([hidden])");
    if (section === "answer") return dom.querySelector(".card-replies");
    if (section === "process")
      return (
        dom.querySelector(".card-status-log:not(:empty)") ||
        dom.querySelector(".card-live-thought") ||
        dom.querySelector(".card-timeline")
      );
    if (section === "followup") return dom.querySelector(".card-followup");
    return dom.querySelector(".cmd-action-card-head");
  }

  function scrollSection(section) {
    var ctx = _ctx || {};
    var actionState = typeof ctx.getActionState === "function" ? ctx.getActionState() : null;
    var cardId = actionState ? actionState.detailCardId : null;
    var dom = cardId ? document.getElementById("card-" + cardId) : null;
    var results = document.getElementById("results");
    var target = sectionTarget(dom, section);
    if (!target || !results) return;
    var resultsRect = results.getBoundingClientRect();
    var targetRect = target.getBoundingClientRect();
    results.scrollTo({
      top: results.scrollTop + targetRect.top - resultsRect.top - 112,
      behavior: "smooth"
    });
    var nav = results.querySelector(".action-detail-nav");
    if (nav) {
      nav.querySelectorAll(".action-detail-tab").forEach(function (btn) {
        btn.classList.toggle("active", btn.getAttribute("data-section") === section);
      });
    }
  }

  function ensureNav(stack) {
    if (!stack) return null;
    var nav = stack.querySelector(":scope > .action-detail-nav");
    if (nav) return nav;
    var ctx = _ctx || {};
    nav = document.createElement("div");
    nav.className = "action-detail-nav";
    nav.innerHTML =
      '<button type="button" class="action-detail-back">← 任务列表</button>' +
      '<div class="action-detail-identity">' +
      '<div class="action-detail-breadcrumb"><span>任务</span><span>/</span><span class="crumb-state"></span><span>/</span><span class="crumb-current"></span></div>' +
      '<div class="action-detail-title"></div></div>' +
      '<div class="action-detail-tabs">' +
      '<button type="button" class="action-detail-tab" data-section="structure">结构</button>' +
      '<button type="button" class="action-detail-tab" data-section="answer">回答</button>' +
      '<button type="button" class="action-detail-tab" data-section="process">过程</button>' +
      '<button type="button" class="action-detail-tab" data-section="followup">补充</button>' +
      "</div>";
    stack.insertBefore(nav, stack.firstChild);
    nav.querySelector(".action-detail-back").addEventListener("click", function () {
      if (typeof ctx.closeActionCardDetail === "function") ctx.closeActionCardDetail();
    });
    nav.querySelectorAll(".action-detail-tab").forEach(function (btn) {
      btn.addEventListener("click", function () {
        scrollSection(btn.getAttribute("data-section") || "top");
      });
    });
    return nav;
  }

  function syncNav() {
    var ctx = _ctx || {};
    var state = typeof ctx.getState === "function" ? ctx.getState() : null;
    var actionState = typeof ctx.getActionState === "function" ? ctx.getActionState() : null;
    var getActionCard = typeof ctx.getActionCard === "function" ? ctx.getActionCard : function () { return null; };
    var actionCardUiLabel = typeof ctx.actionCardUiLabel === "function" ? ctx.actionCardUiLabel : function () { return ""; };
    var agentProviderLabel = typeof ctx.agentProviderLabel === "function" ? ctx.agentProviderLabel : function () { return ""; };

    var box = document.getElementById("results");
    var stack = box && box.querySelector(".action-card-stack");
    var panel = document.getElementById("palette-panel");
    var cardId = actionState ? actionState.detailCardId : null;
    var card = cardId ? getActionCard(cardId) : null;
    if (!box || !stack || !card) {
      if (stack) stack.classList.remove("detail-mode");
      if (box) box.classList.remove("action-detail-mode");
      if (panel) panel.classList.remove("action-detail-open");
      return;
    }
    var nav = ensureNav(stack);
    var dom = document.getElementById("card-" + cardId);
    stack.classList.add("detail-mode");
    box.classList.add("action-detail-mode");
    if (panel) panel.classList.add("action-detail-open");
    if (!nav) return;
    var title = card.title || card.query || "代理任务";
    var stateEl = nav.querySelector(".crumb-state");
    var currentEl = nav.querySelector(".crumb-current");
    var titleEl = nav.querySelector(".action-detail-title");
    if (stateEl) stateEl.textContent = actionCardUiLabel(card.uiState);
    if (currentEl) currentEl.textContent = agentProviderLabel(card.provider || (state && state.agentProvider));
    if (titleEl) titleEl.textContent = title;
    nav.querySelectorAll(".action-detail-tab").forEach(function (btn) {
      var section = btn.getAttribute("data-section") || "";
      var target = sectionTarget(dom, section);
      var empty =
        !target ||
        target.hidden ||
        (section === "answer" && !target.querySelector(".card-reply, .card-reply-segment")) ||
        (section === "process" && !String(target.textContent || "").trim());
      btn.hidden = empty;
      if (empty) btn.classList.remove("active");
    });
    var activeTab = nav.querySelector(".action-detail-tab.active:not([hidden])");
    if (!activeTab) {
      var firstTab = nav.querySelector(".action-detail-tab:not([hidden])");
      if (firstTab) firstTab.classList.add("active");
    }
  }

  global.PaletteDetailPane = {
    install: install,
    sectionTarget: sectionTarget,
    scrollSection: scrollSection,
    ensureNav: ensureNav,
    syncNav: syncNav
  };
})(typeof window !== "undefined" ? window : globalThis);
