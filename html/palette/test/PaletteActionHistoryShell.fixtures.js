(function (global) {
  "use strict";

  function makeClassList() {
    var set = Object.create(null);
    return {
      add: function (c) {
        set[c] = true;
      },
      toggle: function (c, on) {
        if (on === false) delete set[c];
        else set[c] = !set[c];
      },
      contains: function (c) {
        return !!set[c];
      }
    };
  }

  function makeEl(tag, opts) {
    opts = opts || {};
    var el = {
      tagName: String(tag || "div").toUpperCase(),
      className: opts.className || "",
      id: opts.id || "",
      innerHTML: "",
      style: {},
      hidden: false,
      children: [],
      parentNode: null,
      attributes: Object.create(null),
      classList: makeClassList(),
      _docRegistry: opts.registry || null,
      setAttribute: function (k, v) {
        this.attributes[k] = String(v);
      },
      getAttribute: function (k) {
        return this.attributes[k] != null ? this.attributes[k] : null;
      },
      appendChild: function (child) {
        child.parentNode = this;
        this.children.push(child);
        return child;
      },
      insertBefore: function (child, ref) {
        child.parentNode = this;
        if (!ref) {
          this.children.unshift(child);
          return child;
        }
        var idx = this.children.indexOf(ref);
        if (idx < 0) this.children.push(child);
        else this.children.splice(idx, 0, child);
        return child;
      },
      remove: function () {
        if (!this.parentNode) return;
        var p = this.parentNode.children;
        var i = p.indexOf(this);
        if (i >= 0) p.splice(i, 1);
        this.parentNode = null;
        if (this.id && this._docRegistry && this._docRegistry[this.id] === this) {
          delete this._docRegistry[this.id];
        }
      },
      querySelector: function (sel) {
        return querySel(this, sel, false);
      },
      querySelectorAll: function (sel) {
        return querySel(this, sel, true) || [];
      },
      addEventListener: function () {},
      removeEventListener: function () {},
      contains: function (node) {
        if (!node) return false;
        if (node === this) return true;
        for (var i = 0; i < this.children.length; i++) {
          if (this.children[i].contains(node)) return true;
        }
        return false;
      },
      closest: function () {
        return null;
      }
    };
    if (opts.id) el.id = opts.id;
    return el;
  }

  function querySel(root, sel, all) {
    var hits = [];
    function walk(node) {
      if (!node || !node.children) return;
      for (var i = 0; i < node.children.length; i++) {
        var c = node.children[i];
        if (matchSel(c, sel)) hits.push(c);
        walk(c);
      }
    }
    walk(root);
    if (all) return hits;
    return hits.length ? hits[0] : null;
  }

  function matchSel(el, sel) {
    if (!el || !sel) return false;
    if (sel.indexOf("[") >= 0) {
      var lb = sel.indexOf("[");
      var rb = sel.lastIndexOf("]");
      var cls = sel.slice(0, lb).replace(/^\./, "");
      var attrPart = sel.slice(lb + 1, rb);
      var eq = attrPart.indexOf("=");
      var key = eq >= 0 ? attrPart.slice(0, eq) : attrPart;
      var val = eq >= 0 ? attrPart.slice(eq + 1).replace(/^['"]|['"]$/g, "") : null;
      if (cls && el.className.split(/\s+/).indexOf(cls) < 0) return false;
      if (val != null) return el.getAttribute(key) === val;
      return el.getAttribute(key) != null;
    }
    if (sel.charAt(0) === ".") return el.className.split(/\s+/).indexOf(sel.slice(1)) >= 0;
    if (sel.charAt(0) === "#") return el.id === sel.slice(1);
    return el.tagName === sel.toUpperCase();
  }

  function makeMiniDocument() {
    var byId = Object.create(null);
    var results = makeEl("div", { id: "results", className: "palette-results", registry: byId });
    var loading = makeEl("div", { id: "action-history-loading", className: "action-history-loading", registry: byId });
    loading.textContent = "加载历史任务…";
    results.appendChild(loading);
    byId.results = results;
    byId["action-history-loading"] = loading;
    var panel = makeEl("section", { id: "palette-panel" });
    byId["palette-panel"] = panel;
    return {
      getElementById: function (id) {
        return byId[id] || null;
      },
      createElement: function (tag) {
        return makeEl(tag, { registry: byId });
      }
    };
  }

  function makeMockApi(doc, actionState, state) {
    actionState = actionState || { cards: {}, historyFilter: "all", showAllDone: false, detailCardId: null };
    state = state || { intent: "action", input: "", actionCmdBrowse: false, agentProvider: "openclaw" };
    return {
      state: state,
      actionState: actionState,
      hideCardHoverPreview: function () {},
      clearActionHistoryLoading: function () {
        var el = doc.getElementById("action-history-loading");
        if (el && el.remove) el.remove();
      },
      syncExpandedCardsToHistoryFilter: function () {},
      purgeActionEmptyHint: function () {
        var box = doc.getElementById("results");
        if (!box) return;
        var hints = box.querySelectorAll(".action-intent-empty");
        hints.forEach(function (n) {
          if (n.remove) n.remove();
        });
      },
      refreshActionHistoryHead: function () {
        var box = doc.getElementById("results");
        if (!box) return;
        var stack = box.querySelector(".action-card-stack");
        if (!stack) return;
        var toolbar = stack.querySelector(".action-history-toolbar");
        if (!toolbar) {
          toolbar = doc.createElement("div");
          toolbar.className = "action-history-toolbar";
          toolbar.innerHTML =
            '<button type="button" class="action-history-filter active" data-filter="all">全部</button>' +
            '<button type="button" class="action-history-filter" data-filter="running">进行中</button>' +
            '<button type="button" class="action-history-filter" data-filter="done">已归档</button>';
          stack.insertBefore(toolbar, stack.firstChild);
        }
        toolbar.style.display = "flex";
      },
      removeActionLiveDock: function () {},
      cardMatchesHistoryFilter: function () {
        return true;
      },
      isActionCardRunning: function (card) {
        return !!(card && card.uiState !== "Done");
      },
      sortCardIds: function (ids) {
        return ids.sort();
      },
      ensureActionCardSection: function (stack, sectionId) {
        if (!stack) return null;
        var sec = stack.querySelector('.action-card-section[data-section="' + sectionId + '"]');
        if (!sec) {
          sec = doc.createElement("div");
          sec.className = "action-card-section";
          sec.setAttribute("data-section", sectionId);
          var head = doc.createElement("div");
          head.className = "action-card-section-head";
          var list = doc.createElement("div");
          list.className = "action-card-list";
          sec.appendChild(head);
          sec.appendChild(list);
          stack.appendChild(sec);
        }
        return sec;
      },
      mountActionCardIntoList: function (card, listHost) {
        if (!card || !listHost) return;
        var dom = doc.createElement("div");
        dom.id = "card-" + card.id;
        dom.className = "cmd-action-card";
        dom.textContent = card.title || card.id;
        listHost.appendChild(dom);
      },
      historyFilterEmptyMessage: function () {
        return "当前筛选无任务";
      },
      agentProviderLabel: function () {
        return "龙虾";
      },
      replayExpandedCardPipelineBlocks: function () {},
      syncActionDetailNav: function () {},
      syncActionListLayout: function () {},
      collapseNonActiveCards: function () {},
      removeActionCard: function () {},
      scheduleActionCommandPaint: function () {},
      paletteFastInput: function () {
        return false;
      },
      updateResults: function () {}
    };
  }

  function assert(cond, msg) {
    if (!cond) throw new Error(msg);
  }

  function runActionHistoryShellFixtures() {
    if (typeof PaletteAgentSummary === "undefined") {
      throw new Error("PaletteAgentSummary missing");
    }
    if (typeof global.requestAnimationFrame !== "function") {
      global.requestAnimationFrame = function (fn) {
        if (typeof fn === "function") fn();
      };
    }

    var doc = makeMiniDocument();
    global.document = doc;
    var api = makeMockApi(doc);
    PaletteAgentSummary.install(api);
    PaletteAgentSummary.renderActionHistoryList();

    var results = doc.getElementById("results");
    assert(!doc.getElementById("action-history-loading"), "history_empty: loading indicator should clear");
    var stack = results.querySelector(".action-card-stack");
    assert(stack, "history_empty: action-card-stack missing");
    var toolbar = stack.querySelector(".action-history-toolbar");
    assert(toolbar, "history_empty: toolbar missing");
    assert(toolbar.style.display === "flex", "history_empty: toolbar should stay visible");
    var empty = stack.querySelector(".action-intent-empty");
    assert(empty, "history_empty: empty hint missing");

    doc = makeMiniDocument();
    global.document = doc;
    var actionState = {
      cards: {
        "card-done-1": {
          id: "card-done-1",
          uiState: "Done",
          title: "测试归档任务",
          expanded: false,
          updatedAt: "2026-06-12T10:00:00Z"
        }
      },
      historyFilter: "all",
      showAllDone: false,
      detailCardId: null
    };
    api = makeMockApi(doc, actionState);
    PaletteAgentSummary.install(api);
    PaletteAgentSummary.renderActionHistoryList();

    stack = doc.getElementById("results").querySelector(".action-card-stack");
    assert(stack, "history_done: stack missing");
    var doneSec = stack.querySelector('.action-card-section[data-section="done"]');
    assert(doneSec, "history_done: done section missing");
    var cardDom = doneSec.querySelector(".cmd-action-card");
    assert(cardDom && cardDom.textContent.indexOf("测试归档任务") >= 0, "history_done: card not mounted");

    PaletteAgentSummary.install(null);
    try {
      PaletteAgentSummary.renderActionHistoryList();
    } catch (e) {
      throw new Error("history_guard: render should not throw when api unset");
    }

    return { ok: true, cases: 3 };
  }

  global.PaletteActionHistoryShellFixtures = { run: runActionHistoryShellFixtures };
})(typeof globalThis !== "undefined" ? globalThis : this);
