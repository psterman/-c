/**
 * PaletteActionChips Lit + bridge fixtures
 */
(function (root) {
  var FIXTURES = {
    action_chips_lit_descriptor: {
      description: "ActionChips descriptor 校验通过",
      block: {
        type: "a2ui",
        component: "ActionChips",
        id: "blk_lit_desc",
        props: {
          actions: [{ id: "a1", label: "继续", intent: "prefill", payload: { text: "继续" } }]
        }
      }
    },
    action_chips_lit_render_stub: {
      description: "valid ActionChips block 经 Lit renderer 渲染",
      blocks: [
        {
          id: "blk_lit_render",
          type: "a2ui",
          component: "ActionChips",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 1,
          turnId: 1,
          traceId: "fx_lit",
          props: {
            actions: [{ id: "lit1", label: "Lit chip", intent: "prefill", payload: { text: "lit text" } }]
          }
        }
      ]
    },
    action_chips_a2ui_bridge_emit: {
      description: "a2ui-action emit 后 ActionController 被调用",
      card: { id: "card-lit-bridge", uiState: "Done", _submitFollowup: null },
      action: {
        id: "br1",
        label: "Bridge",
        intent: "prefill",
        payload: { text: "bridge prefill" }
      }
    },
    action_chips_disabled_no_emit: {
      description: "disabled chip 不触发 controller",
      action: { id: "dis1", label: "禁用", intent: "prefill", payload: { text: "x" }, disabled: true }
    },
    action_chips_pending_state: {
      description: "pendingActionId 对应 chip 处于 pending",
      pendingActionId: "pend1",
      action: { id: "pend1", label: "等待", intent: "prefill", payload: { text: "p" } }
    },
    action_chips_sync_pending_dom: {
      description: "syncPendingToActionChipsDom 更新 palette-action-chips.pendingActionId",
      cardId: "card-lit-pending-sync"
    },
    action_chips_lit_error_fallback: {
      description: "Lit render error 时 fallback 不影响 card",
      blocks: [
        {
          id: "blk_plan_ok",
          type: "plan",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 1,
          turnId: 1,
          traceId: "fx_err",
          items: [{ text: "步骤", state: "done" }]
        },
        {
          id: "blk_lit_err",
          type: "a2ui",
          component: "ActionChips",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 2,
          turnId: 1,
          traceId: "fx_err",
          props: {
            actions: [{ id: "e1", label: "Err chip", intent: "prefill", payload: { text: "e" } }]
          }
        }
      ],
      forceRenderError: true
    }
  };

  function installStubActionChipsElement() {
    if (root._actionChipsStubInstalled) return;
    function BaseEl() {
      this._attrs = {};
      this.children = [];
      this.classList = { add: function () {}, remove: function () {}, contains: function () { return false; } };
    }
    BaseEl.prototype.setAttribute = function (k, v) {
      this._attrs[k] = v;
    };
    BaseEl.prototype.getAttribute = function (k) {
      return this._attrs[k];
    };
    BaseEl.prototype.removeAttribute = function (k) {
      delete this._attrs[k];
    };
    BaseEl.prototype.appendChild = function (c) {
      this.children.push(c);
      return c;
    };
    function StubActionChips() {
      BaseEl.call(this);
      this.actions = [];
      this.disabled = false;
      this.pendingActionId = "";
      this.selectedActionId = "";
      this.cardId = "";
      this.blockId = "";
      this.tagName = "PALETTE-ACTION-CHIPS";
    }
    StubActionChips.prototype = Object.create(BaseEl.prototype);
    if (!root.HTMLElement) root.HTMLElement = BaseEl;
    if (!root.customElements) {
      root.customElements = { _registry: {}, define: function () {}, get: function () { return null; } };
    }
    root.customElements._registry["palette-action-chips"] = StubActionChips;
    root.customElements.define = function (name, C) {
      this._registry[name] = C;
    };
    root.customElements.get = function (name) {
      return this._registry[name] || null;
    };
    if (!root.Lit) {
      root.Lit = { LitElement: BaseEl, html: function () { return ""; } };
    }
    root._actionChipsStubInstalled = true;
  }

  function isChipInteractionDisabled(compDisabled, action, pendingActionId) {
    return !!compDisabled || !!(action && action.disabled) || !!(pendingActionId && action && action.id === pendingActionId);
  }

  function runLitFixture(name) {
    var fx = FIXTURES[name];
    if (!fx) return { ok: false, error: "unknown_lit_fixture:" + name, fixture: name };

    if (name === "action_chips_lit_descriptor") {
      if (!root.PaletteLitRenderer || !PaletteLitRenderer.validateActionChipsDescriptor) {
        return { ok: false, error: "lit_renderer_missing", fixture: name };
      }
      var desc =
        PaletteLitRenderer.toActionChipsDescriptor &&
        PaletteLitRenderer.toActionChipsDescriptor({ id: "card-lit-desc" }, fx.block);
      return {
        fixture: name,
        ok: !!desc && PaletteLitRenderer.validateActionChipsDescriptor(desc)
      };
    }

    if (name === "action_chips_lit_render_stub") {
      installStubActionChipsElement();
      if (!root.PaletteCardRenderer || !PaletteCardRenderer.renderBlocks) {
        return { ok: false, error: "card_renderer_missing", fixture: name };
      }
      if (!root.PaletteSlotRenderTrace || !PaletteSlotRenderTrace.beginCardRender) {
        return { ok: false, error: "slot_trace_missing", fixture: name };
      }
      var chipsBox = {
        hidden: true,
        innerHTML: "",
        children: [],
        appendChild: function (c) {
          this.children.push(c);
          this.innerHTML = "mounted";
        },
        querySelector: function () {
          return null;
        }
      };
      var dom = {
        querySelector: function (sel) {
          if (sel === ".card-followup-chips") return chipsBox;
          if (sel === ".card-timeline") return { innerHTML: "", appendChild: function () {} };
          if (sel === ".card-status-log") return { innerHTML: "", appendChild: function () {}, querySelector: function () { return null; } };
          if (sel === ".card-replies") return { innerHTML: "", appendChild: function () {}, querySelector: function () { return null; } };
          if (sel === ".card-question") return { hidden: true, innerHTML: "" };
          if (sel === ".card-a2ui") return { hidden: true, innerHTML: "", appendChild: function () {}, querySelector: function () { return null; } };
          return null;
        },
        querySelectorAll: function () {
          return [];
        },
        classList: { toggle: function () {}, contains: function () { return false; } }
      };
      root.document = {
        createElement: function (tag) {
          var C = root.customElements.get(tag);
          return C ? new C() : { setAttribute: function () {}, appendChild: function () {}, removeAttribute: function () {} };
        },
        getElementById: function () {
          return null;
        }
      };
      var card = { id: "card-lit-render", expanded: true, uiState: "Done", pipelineBlocks: fx.blocks };
      var logs = [];
      PaletteCardRenderer.renderBlocks("card-lit-render", dom, fx.blocks, {
        debugLog: function (ev, det) {
          logs.push({ ev: ev, det: det });
        },
        deps: {
          esc: function (t) { return String(t || ""); },
          getActionCard: function () { return card; },
          renderAgentPlainMarkdown: function (t) { return String(t || ""); }
        }
      });
      var snap = PaletteSlotRenderTrace.snapshot("card-lit-render");
      return {
        fixture: name,
        ok:
          snap &&
          snap.ActionChips &&
          snap.ActionChips.renderer === "lit" &&
          chipsBox.children.length === 1 &&
          logs.some(function (l) { return l.ev === "action_chips_lit_rendered"; })
      };
    }

    if (name === "action_chips_a2ui_bridge_emit") {
      if (!root.PaletteA2UIEventBridge || !PaletteA2UIEventBridge.install) {
        return { ok: false, error: "a2ui_bridge_missing", fixture: name };
      }
      var bridgeLogs = [];
      var savedDoc = root.document;
      var listeners = [];
      root.document = {
        addEventListener: function (type, fn) {
          listeners.push({ type: type, fn: fn });
        },
        removeEventListener: function () {}
      };
      if (!root.PaletteActionController || !PaletteActionController.handleA2uiAction) {
        return { ok: false, error: "controller_missing", fixture: name };
      }
      if (PaletteA2UIEventBridge._resetForTest) PaletteA2UIEventBridge._resetForTest();
      var bridgeInput = {
        value: "",
        focusCalled: false,
        dataset: {},
        placeholder: "",
        classList: { add: function () {}, remove: function () {} },
        focus: function () { this.focusCalled = true; },
        addEventListener: function () {}
      };
      var bridgeDom = {
        querySelector: function (sel) {
          if (sel === ".card-followup-input") return bridgeInput;
          return null;
        }
      };
      root.document = {
        getElementById: function (id) {
          return id === "card-" + fx.card.id ? bridgeDom : null;
        },
        createElement: function () {
          return { setAttribute: function () {}, appendChild: function () {} };
        },
        addEventListener: function (type, fn) {
          listeners.push({ type: type, fn: fn });
        },
        removeEventListener: function () {}
      };
      PaletteA2UIEventBridge.install({
        getCard: function () {
          return fx.card;
        },
        debugLog: function (ev, det) {
          bridgeLogs.push({ ev: ev, det: det });
        }
      });
      var target = { getAttribute: function (k) { return k === "card-id" ? fx.card.id : ""; } };
      listeners.forEach(function (l) {
        if (l.type === "a2ui-action") {
          l.fn({ detail: fx.action, target: target });
        }
      });
      if (savedDoc !== undefined) root.document = savedDoc;
      else delete root.document;
      return {
        fixture: name,
        ok:
          bridgeLogs.some(function (l) { return l.ev === "action_chips_lit_event"; }) &&
          bridgeLogs.some(function (l) { return l.ev === "a2ui_action_prefill"; }) &&
          bridgeInput.value === "bridge prefill"
      };
    }

    if (name === "action_chips_disabled_no_emit") {
      var blocked = isChipInteractionDisabled(false, fx.action, "");
      var emitted = !blocked;
      return { fixture: name, ok: blocked && !emitted };
    }

    if (name === "action_chips_pending_state") {
      var pendingBlocked = isChipInteractionDisabled(false, fx.action, fx.pendingActionId);
      var cls = "card-followup-chip";
      if (fx.pendingActionId && fx.action.id === fx.pendingActionId) cls += " is-pending";
      return {
        fixture: name,
        ok: pendingBlocked && cls.indexOf("is-pending") >= 0
      };
    }

    if (name === "action_chips_sync_pending_dom") {
      if (!root.PaletteActionController || !PaletteActionController.syncPendingToActionChipsDom) {
        return { ok: false, error: "controller_missing", fixture: name };
      }
      var litEl = {
        pendingActionId: "",
        actions: [{ id: "sync_p1", label: "Sync" }],
        tagName: "PALETTE-ACTION-CHIPS"
      };
      var chipsBox = {
        children: [litEl],
        querySelector: function (sel) {
          return sel === "palette-action-chips" ? litEl : null;
        }
      };
      var syncDom = {
        querySelector: function (sel) {
          if (sel === ".card-followup-chips") return chipsBox;
          return null;
        }
      };
      var savedSyncDoc = root.document;
      root.document = {
        getElementById: function (id) {
          return id === "card-" + fx.cardId ? syncDom : null;
        }
      };
      var cardSync = { id: fx.cardId, pendingActionId: "sync_p1" };
      try {
        PaletteActionController.syncPendingToActionChipsDom(fx.cardId, cardSync);
        var setOk = litEl.pendingActionId === "sync_p1";
        cardSync.pendingActionId = "";
        PaletteActionController.syncPendingToActionChipsDom(fx.cardId, cardSync);
        return { fixture: name, ok: setOk && litEl.pendingActionId === "" };
      } finally {
        if (savedSyncDoc !== undefined) root.document = savedSyncDoc;
        else delete root.document;
      }
    }

    if (name === "action_chips_lit_error_fallback") {
      installStubActionChipsElement();
      if (!root.PaletteCardRenderer || !PaletteCardRenderer.renderBlocks) {
        return { ok: false, error: "card_renderer_missing", fixture: name };
      }
      root.customElements.get = function () {
        return null;
      };
      var timeline = { innerHTML: "", children: [], appendChild: function (n) { this.children.push(n); } };
      var chipsBox2 = {
        hidden: true,
        innerHTML: "",
        children: [],
        appendChild: function (c) { this.children.push(c); },
        querySelector: function () { return null; }
      };
      var dom2 = {
        querySelector: function (sel) {
          if (sel === ".card-followup-chips") return chipsBox2;
          if (sel === ".card-timeline") return timeline;
          if (sel === ".card-status-log") return { innerHTML: "", appendChild: function () {}, querySelector: function () { return null; } };
          if (sel === ".card-replies") return { innerHTML: "", appendChild: function () {}, querySelector: function () { return null; } };
          if (sel === ".card-question") return { hidden: true, innerHTML: "" };
          if (sel === ".card-a2ui") return { hidden: true, innerHTML: "", appendChild: function () {}, querySelector: function () { return null; } };
          return null;
        },
        querySelectorAll: function () { return []; },
        classList: { toggle: function () {}, contains: function () { return false; } }
      };
      root.document = {
        createElement: function (tag) {
          var C = root.customElements.get(tag);
          return C ? new C() : { setAttribute: function () {}, appendChild: function () {}, removeAttribute: function () {} };
        },
        getElementById: function () {
          return null;
        }
      };
      var card2 = { id: "card-lit-err", expanded: true, uiState: "Done", pipelineBlocks: fx.blocks };
      var errLogs = [];
      var out = PaletteCardRenderer.renderBlocks("card-lit-err", dom2, fx.blocks, {
        debugLog: function (ev, det) { errLogs.push({ ev: ev, det: det }); },
        deps: {
          esc: function (t) { return String(t || ""); },
          getActionCard: function () { return card2; },
          renderAgentPlainMarkdown: function (t) { return String(t || ""); }
        }
      });
      var errSnap = PaletteSlotRenderTrace.snapshot("card-lit-err");
      return {
        fixture: name,
        ok:
          out &&
          out.ok &&
          timeline.children.length === 1 &&
          errSnap &&
          errSnap.ActionChips &&
          errSnap.ActionChips.renderer === "legacy" &&
          errSnap.plan &&
          errSnap.plan.count === 1
      };
    }

    return { ok: false, error: "unhandled_fixture", fixture: name };
  }

  function withMockDom(cardId, fn) {
    var mockInput = {
      value: "",
      focusCalled: false,
      dataset: {},
      placeholder: "",
      classList: { add: function () {}, remove: function () {} },
      focus: function () { this.focusCalled = true; },
      addEventListener: function () {}
    };
    var mockDom = {
      querySelector: function (sel) {
        if (sel === ".card-followup-input") return mockInput;
        return null;
      }
    };
    var savedDoc = root.document;
    root.document = {
      getElementById: function (id) {
        return id === "card-" + cardId ? mockDom : null;
      }
    };
    var out;
    try {
      out = fn(mockInput);
    } finally {
      if (savedDoc !== undefined) root.document = savedDoc;
      else delete root.document;
    }
    return { out: out, mockInput: mockInput };
  }

  function runAllLitFixtures() {
    var names = Object.keys(FIXTURES);
    var results = [];
    var passed = 0;
    var failed = 0;
    for (var i = 0; i < names.length; i++) {
      var out = runLitFixture(names[i]);
      results.push(out);
      if (out.ok) passed++;
      else failed++;
    }
    return { ok: failed === 0, passed: passed, failed: failed, results: results };
  }

  root.PaletteActionChipsLitFixtures = {
    FIXTURES: FIXTURES,
    runLitFixture: runLitFixture,
    runAllLitFixtures: runAllLitFixtures
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
