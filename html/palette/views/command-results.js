(function (global) {
  "use strict";

  var _ctx = null;

  function install(ctx) {
    _ctx = ctx || {};
  }

  function ctxCall(name) {
    var args = Array.prototype.slice.call(arguments, 1);
    if (_ctx && typeof _ctx[name] === "function") return _ctx[name].apply(_ctx, args);
    return undefined;
  }

  function bindResultsScrollHide(box) {
    if (!box || box.dataset.scrollBound) return;
    box.dataset.scrollBound = "1";
    box.addEventListener(
      "scroll",
      function () {
        box.classList.add("is-scrolling");
        var timer = ctxCall("getScrollHideTimer");
        if (timer) clearTimeout(timer);
        timer = setTimeout(function () {
          box.classList.remove("is-scrolling");
          ctxCall("setScrollHideTimer", 0);
        }, 750);
        ctxCall("setScrollHideTimer", timer);
      },
      { passive: true }
    );
  }

  function renderTurboResults(box, rows) {
    var state = ctxCall("getState");
    var kindIcon = _ctx.kindIcon;
    if (!state || typeof kindIcon !== "function") return;
    var frag = document.createDocumentFragment();
    var cap = Math.min(20, rows.length);
    for (var i = 0; i < cap; i++) {
      var item = rows[i];
      var btn = document.createElement("button");
      btn.type = "button";
      btn.className = "result-item kind-file" + (i === state.selected ? " active" : "");
      btn.setAttribute("data-idx", String(i));
      if (item.path) btn.setAttribute("data-path", item.path);
      var icon = document.createElement("span");
      icon.className = "result-icon";
      icon.setAttribute("aria-hidden", "true");
      icon.textContent = kindIcon(item.kind || "file");
      var body = document.createElement("span");
      body.className = "result-body";
      var title = document.createElement("span");
      title.className = "result-title";
      title.textContent = item.label || item.title || "";
      var desc = document.createElement("span");
      desc.className = "result-desc";
      desc.textContent = item.desc || item.subtitle || item.path || "";
      body.appendChild(title);
      body.appendChild(desc);
      btn.appendChild(icon);
      btn.appendChild(body);
      frag.appendChild(btn);
    }
    box.replaceChildren(frag);
  }

  function renderCommandResults(box, rows) {
    var state = ctxCall("getState");
    if (!box || !state) return;
    if (state.intent === "action" && box.id === "results") {
      renderActionCmdList(rows);
      return;
    }
    var limited = rows;
    if (typeof global.PaletteResultList !== "undefined") {
      limited = rows.slice(0, global.PaletteResultList.MAX_ROWS);
    }
    var buildRow = _ctx.buildCommandResultRowHtml;
    var hydrate = _ctx.hydrateResultIcons;
    if (ctxCall("paletteFastInput") && typeof global.PaletteResultList !== "undefined" && typeof buildRow === "function") {
      global.PaletteResultList.patchList(box, limited, state.selected, buildRow, {
        hydrateFn: hydrate
      });
      return;
    }
    if (typeof buildRow === "function") {
      box.innerHTML = limited
        .map(function (item, idx) {
          return buildRow(item, idx, idx === state.selected);
        })
        .join("");
    }
    if (typeof hydrate === "function") hydrate(box);
  }

  function renderActionCmdList(rows) {
    var state = ctxCall("getState");
    if (!state) return;
    var box = document.getElementById("results");
    if (!box) return;
    var cmdHost = box.querySelector(".action-cmd-list");
    if (!rows || !rows.length) {
      if (cmdHost) cmdHost.remove();
      return;
    }
    if (!cmdHost) {
      cmdHost = document.createElement("div");
      cmdHost.className = "action-cmd-list";
      box.appendChild(cmdHost);
    }
    if (state.resultMode === "turbo") renderTurboResults(cmdHost, rows);
    else renderCommandResults(cmdHost, rows);
    bindResultClicks(cmdHost);
  }

  function bindResultClicks(box) {
    if (!box || box.dataset.clickDelegated) return;
    box.dataset.clickDelegated = "1";
    box.addEventListener("click", function (e) {
      var state = ctxCall("getState");
      if (!state) return;
      var node = e.target && e.target.closest ? e.target.closest("[data-idx]") : null;
      if (!node || !box.contains(node)) return;
      var idx = Number(node.getAttribute("data-idx"));
      if (idx < 0 || isNaN(idx)) return;
      state.selected = idx;
      var rows = ctxCall("currentRows");
      var item = rows && rows[idx];
      if (item && item.kind === "ai_provider") {
        ctxCall("pickAiProvider", item.id);
        return;
      }
      updateResults();
      ctxCall("executeSelected");
    });
  }

  function updateResults() {
    var state = ctxCall("getState");
    var aiPhase = ctxCall("getAiPhase");
    if (!state) return;
    if (aiPhase === "compact" && state.intent === "ai") {
      ctxCall("refreshAiProvidersUnderCard");
      return;
    }
    if (state.intent === "action") ctxCall("purgeAiResultsDom");
    var box = document.getElementById("results");
    var panel = document.getElementById("palette-panel");
    if (!box || !panel) return;
    var rows = ctxCall("currentRows") || [];
    var hasActionCards = ctxCall("actionHasStoredCards") || !!box.querySelector(".cmd-action-card");
    state.showResults = rows.length > 0 || hasActionCards || state.intent === "action";
    panel.classList.toggle("has-results", state.showResults);
    panel.classList.toggle("has-ai-providers", state.intent === "ai" && rows.length > 0);
    box.classList.toggle("has-action-cards", hasActionCards);
    box.classList.toggle("show-cmd-browse", !!state.actionCmdBrowse);
    if (state.intent === "action" && !hasActionCards && !state.actionCmdBrowse && !state.input.trim()) {
      ctxCall("maybeRequestAgentCardSync");
      ctxCall("renderActionHistoryList");
      ctxCall("purgeActionEmptyHint");
      ctxCall("syncWindowSize");
      return;
    }
    if (state.intent === "action" && hasActionCards && state._actionCmdQueryActive && state.input.trim() && rows.length) {
      ctxCall("updateActionCmdOverlay", rows);
      return;
    }
    if (state.intent === "action" && hasActionCards) {
      ctxCall("renderActionHistoryList");
      var cmdHost = box.querySelector(".action-cmd-list");
      if (!rows.length || !state.actionCmdBrowse) {
        if (cmdHost) cmdHost.remove();
      } else {
        if (!cmdHost) {
          cmdHost = document.createElement("div");
          cmdHost.className = "action-cmd-list";
          box.appendChild(cmdHost);
        }
        if (state.resultMode === "turbo") renderTurboResults(cmdHost, rows);
        else renderCommandResults(cmdHost, rows);
        bindResultClicks(cmdHost);
        var activeNode = cmdHost.querySelector(".result-item.active");
        if (activeNode) ctxCall("scrollResultItemIntoView", box, activeNode);
      }
      bindResultsScrollHide(box);
      ctxCall("syncWindowSize");
      return;
    }
    if (state.intent === "action") {
      if (hasActionCards) {
        ctxCall("renderActionHistoryList");
        if (state.actionCmdBrowse && rows.length) renderActionCmdList(rows);
        else {
          var ch = box.querySelector(".action-cmd-list");
          if (ch) ch.remove();
        }
      } else if (state.actionCmdBrowse && rows.length) {
        renderActionCmdList(rows);
      } else if (!state.input.trim()) {
        ctxCall("maybeRequestAgentCardSync");
        if (!ctxCall("actionHasStoredCards")) ctxCall("showActionEmptyIfNeeded");
        return;
      }
      bindResultsScrollHide(box);
      ctxCall("syncWindowSize");
      return;
    }
    box.className = "palette-results" + (hasActionCards ? " has-action-cards" : "");
    if (state.resultMode === "turbo") renderTurboResults(box, rows);
    else renderCommandResults(box, rows);
    bindResultsScrollHide(box);
    bindResultClicks(box);
    var activeNode2 = box.querySelector(".result-item.active");
    if (activeNode2) ctxCall("scrollResultItemIntoView", box, activeNode2);
    ctxCall("syncWindowSize");
  }

  global.PaletteCommandResults = {
    install: install,
    bindResultsScrollHide: bindResultsScrollHide,
    renderTurboResults: renderTurboResults,
    renderCommandResults: renderCommandResults,
    renderActionCmdList: renderActionCmdList,
    bindResultClicks: bindResultClicks,
    updateResults: updateResults
  };
})(typeof window !== "undefined" ? window : globalThis);
