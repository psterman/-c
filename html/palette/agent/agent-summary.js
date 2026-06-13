(function (global) {
  "use strict";
  var api = null;
  var _renderActionHistoryLock = false;
  function install(ctx) {
    api = ctx || null;
  }
  function renderActionHistoryList() {
        if (!api) return;
        if (_renderActionHistoryLock) return;
        _renderActionHistoryLock = true;
        try {
        if (typeof api.clearActionHistoryLoading === "function") api.clearActionHistoryLoading();
        api.hideCardHoverPreview();
        var box = document.getElementById("results");
        if (!box) return;
        api.syncExpandedCardsToHistoryFilter();
        if (Object.keys(api.actionState.cards).length > 0) api.purgeActionEmptyHint();
        var stack = box.querySelector(".action-card-stack");
        if (!stack) {
          stack = document.createElement("div");
          stack.className = "action-card-stack";
          var cmdKeep = box.querySelector(".action-cmd-list");
          if (cmdKeep) box.insertBefore(stack, cmdKeep);
          else box.insertBefore(stack, box.firstChild);
        }
        refreshActionHistoryHead();
        api.removeActionLiveDock(stack);
    
        var oldFlat = stack.querySelector(":scope > .action-card-list");
        if (oldFlat) oldFlat.remove();
        stack.querySelectorAll(".action-done-more-btn").forEach(function (b) {
          b.remove();
        });
    
        var runningIds = [];
        var doneIds = [];
        Object.keys(api.actionState.cards).forEach(function (cid) {
          var c = api.actionState.cards[cid];
          if (!c) return;
          if (!api.cardMatchesHistoryFilter(c)) {
            var hideEl = document.getElementById("card-" + cid);
            if (hideEl) hideEl.style.display = "none";
            return;
          }
          if (api.isActionCardRunning(c)) runningIds.push(cid);
          else doneIds.push(cid);
        });
    
        api.sortCardIds(runningIds);
        api.sortCardIds(doneIds);
    
        var showRunning = api.actionState.historyFilter === "all" || api.actionState.historyFilter === "running";
        var showDone = api.actionState.historyFilter === "all" || api.actionState.historyFilter === "done";
    
        stack.querySelectorAll(".action-card-section").forEach(function (sec) {
          sec.style.display = "none";
        });
    
        if (showRunning && runningIds.length) {
          var runSec = api.ensureActionCardSection(stack, "running");
          runSec.style.display = "";
          var runHead = runSec.querySelector(".action-card-section-head");
          if (runHead) {
            runHead.innerHTML =
              '<span>进行中</span><span class="section-count">' + runningIds.length + "</span>" +
              '<span class="section-hint">实时进度与操作见下方任务卡</span>';
          }
          var runList = runSec.querySelector(".action-card-list");
          if (runList) {
            runList.innerHTML = "";
            runningIds.forEach(function (cid) {
              var card = api.actionState.cards[cid];
              if (!card) return;
              card.expanded = api.actionState.detailCardId === cid;
              api.mountActionCardIntoList(card, runList);
            });
          }
        }
    
        if (showDone && doneIds.length) {
          var doneSec = api.ensureActionCardSection(stack, "done");
          doneSec.style.display = "";
          var doneHead = doneSec.querySelector(".action-card-section-head");
          var doneLimit = api.actionState.showAllDone ? doneIds.length : 4;
          var doneVisible = doneIds.slice(0, doneLimit);
          if (
            api.actionState.detailCardId &&
            doneIds.indexOf(api.actionState.detailCardId) >= 0 &&
            doneVisible.indexOf(api.actionState.detailCardId) < 0
          ) {
            doneVisible.push(api.actionState.detailCardId);
          }
          if (doneHead) {
            doneHead.innerHTML =
              '<span>已归档</span><span class="section-count">' + doneIds.length + "</span>" +
              '<span class="section-hint">默认紧凑 · 悬浮看各轮摘要 · 点击展开</span>';
          }
          var doneList = doneSec.querySelector(".action-card-list");
          if (doneList) {
            doneList.innerHTML = "";
            doneVisible.forEach(function (cid) {
              var card = api.actionState.cards[cid];
              if (!card) return;
              card.expanded = api.actionState.detailCardId === cid;
              api.mountActionCardIntoList(card, doneList);
            });
          }
          if (!api.actionState.showAllDone && doneIds.length > doneLimit) {
            var moreBtn = document.createElement("button");
            moreBtn.type = "button";
            moreBtn.className = "action-done-more-btn";
            moreBtn.textContent = "展开更多已归档（+" + (doneIds.length - doneLimit) + "）";
            moreBtn.addEventListener("click", function () {
              api.actionState.showAllDone = true;
              renderActionHistoryList();
            });
            doneSec.appendChild(moreBtn);
          }
        }
    
        stack.querySelectorAll(".action-filter-empty").forEach(function (n) {
          n.remove();
        });
    
        if (runningIds.length + doneIds.length > 0) {
          var panel = document.getElementById("palette-panel");
          if (panel) panel.classList.add("has-results", "intent-action");
          box.classList.add("palette-results", "has-action-cards");
        } else {
          api.removeActionLiveDock(stack);
          if (Object.keys(api.actionState.cards).length > 0) {
            var filtEmpty = document.createElement("div");
            filtEmpty.className = "action-intent-empty action-filter-empty";
            filtEmpty.textContent = api.historyFilterEmptyMessage();
            stack.appendChild(filtEmpty);
          } else if (
            api.state.intent === "action" &&
            !api.state.input.trim() &&
            !api.state.actionCmdBrowse
          ) {
            api.purgeActionEmptyHint();
            var empty = document.createElement("div");
            empty.className = "action-intent-empty";
            empty.textContent =
              "暂无历史任务。输入描述后 Enter 提交至 " +
              api.agentProviderLabel(api.state.agentProvider) +
              "；提交后会在此按「进行中 / 已归档」分区显示。";
            stack.appendChild(empty);
          }
        }
        api.replayExpandedCardPipelineBlocks();
        api.syncActionDetailNav();
        requestAnimationFrame(api.syncActionListLayout);
        } finally {
          _renderActionHistoryLock = false;
        }
  }
  function refreshActionHistoryHead() {
    if (!api) return;
    var box = document.getElementById("results");
    if (!box) return;
    var stack = box.querySelector(".action-card-stack");
    if (!stack) {
      if (Object.keys(api.actionState.cards).length < 1) return;
      stack = document.createElement("div");
      stack.className = "action-card-stack";
      box.insertBefore(stack, box.firstChild);
    }
    var toolbar = stack.querySelector(".action-history-toolbar");
    if (!toolbar) {
      toolbar = document.createElement("div");
      toolbar.className = "action-history-toolbar";
      toolbar.innerHTML =
        '<button type="button" class="action-history-filter active" data-filter="all">全部</button>' +
        '<button type="button" class="action-history-filter" data-filter="running">进行中</button>' +
        '<button type="button" class="action-history-filter" data-filter="done">已归档</button>' +
        '<button type="button" class="action-history-tool action-focus-mode" title="只展开当前任务">聚焦当前</button>' +
        '<button type="button" class="action-history-tool action-collapse-others" title="折叠非当前任务">折叠其他</button>' +
        '<button type="button" class="action-history-browse-cmd">本地命令</button>' +
        '<button type="button" class="action-history-clear">清除已完成</button>';
      stack.insertBefore(toolbar, stack.firstChild);
      var browseBtn = toolbar.querySelector(".action-history-browse-cmd");
      if (browseBtn) {
        browseBtn.addEventListener("click", function () {
          api.state.actionCmdBrowse = !api.state.actionCmdBrowse;
          browseBtn.classList.toggle("active", api.state.actionCmdBrowse);
          browseBtn.textContent = api.state.actionCmdBrowse ? "隐藏本地命令" : "本地命令";
          var rbox = document.getElementById("results");
          if (rbox) rbox.classList.toggle("show-cmd-browse", api.state.actionCmdBrowse);
          if (api.state.actionCmdBrowse && api.state._actionQueryCache && api.state._actionQueryCache.length) {
            api.state.actions = api.state._actionQueryCache.slice();
          }
          if (api.paletteFastInput() && api.state.actionCmdBrowse && api.state.input.trim()) {
            api.scheduleActionCommandPaint(api.state.input.trim());
          } else {
            api.updateResults();
          }
        });
      }
      toolbar.querySelectorAll(".action-history-filter").forEach(function (btn) {
        btn.addEventListener("click", function () {
          api.actionState.historyFilter = btn.getAttribute("data-filter") || "all";
          toolbar.querySelectorAll(".action-history-filter").forEach(function (b) {
            b.classList.toggle("active", b === btn);
          });
          renderActionHistoryList();
        });
      });
      var focusBtn = toolbar.querySelector(".action-focus-mode");
      if (focusBtn) {
        focusBtn.addEventListener("click", function () {
          api.actionState.focusMode = !api.actionState.focusMode;
          focusBtn.classList.toggle("active", api.actionState.focusMode);
          if (api.actionState.focusMode) api.collapseNonActiveCards();
          renderActionHistoryList();
        });
      }
      var collapseBtn = toolbar.querySelector(".action-collapse-others");
      if (collapseBtn) {
        collapseBtn.addEventListener("click", function () {
          api.collapseNonActiveCards();
          renderActionHistoryList();
        });
      }
      var clr = toolbar.querySelector(".action-history-clear");
      if (clr) {
        clr.addEventListener("click", function () {
          Object.keys(api.actionState.cards).forEach(function (id) {
            var c = api.actionState.cards[id];
            if (c && c.uiState === "Done") api.removeActionCard(id);
          });
          renderActionHistoryList();
          api.syncActionResultsLayout();
        });
      }
    }
    var head = stack.querySelector(".action-history-head");
    var n = Object.keys(api.actionState.cards).length;
    var runN = 0;
    var doneN = 0;
    Object.keys(api.actionState.cards).forEach(function (id) {
      var c = api.actionState.cards[id];
      if (!c) return;
      if (c.uiState === "Done") doneN++;
      else runN++;
    });
    if (n < 1) {
      if (head) head.remove();
      if (toolbar) toolbar.style.display = "flex";
      return;
    }
    if (toolbar) toolbar.style.display = "flex";
    if (!head) {
      head = document.createElement("div");
      head.className = "action-history-head";
      var tb = stack.querySelector(".action-history-toolbar");
      if (tb && tb.nextSibling) stack.insertBefore(head, tb.nextSibling);
      else stack.insertBefore(head, stack.firstChild);
    }
    head.textContent =
      "任务 · 共 " +
      n +
      " 张（进行中 " +
      runN +
      " · 已归档 " +
      doneN +
      "）→ " +
      api.agentProviderLabel(api.state.agentProvider);
  }
  global.PaletteAgentSummary = {
    install: install,
    renderActionHistoryList: renderActionHistoryList,
    refreshActionHistoryHead: refreshActionHistoryHead
  };
})(typeof window !== "undefined" ? window : globalThis);
