/**
 * ActionChips MVP 测试辅助（仅 fixture runner 加载，不进入生产 HTML）
 */
(function (root) {
  var __testOnly = {};

  function installLitStub(opts) {
    opts = opts || {};
    function BaseEl() {
      this._attrs = {};
      this.children = [];
      this.classList = {
        add: function () {},
        remove: function () {},
        contains: function () {
          return false;
        }
      };
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
    if (opts.throwOnApplyProps && root.PaletteCardSlots && PaletteCardSlots.COMPONENTS) {
      var def = PaletteCardSlots.COMPONENTS.ActionChips;
      if (def) {
        opts._savedApplyProps = def.applyProps;
        def.applyProps = function () {
          throw new Error("lit_render_fail_fixture");
        };
      }
    }
    root.HTMLElement = BaseEl;
    root.Lit = { LitElement: BaseEl, html: function () {} };
    root.customElements = {
      _registry: { "palette-action-chips": StubActionChips },
      define: function (name, C) {
        this._registry[name] = C;
      },
      get: function (name) {
        if (opts.hideLit) return null;
        return this._registry[name] || null;
      }
    };
    return {
      restore: function () {
        if (opts._savedApplyProps && root.PaletteCardSlots && PaletteCardSlots.COMPONENTS) {
          PaletteCardSlots.COMPONENTS.ActionChips.applyProps = opts._savedApplyProps;
        }
      }
    };
  }

  function makeMockInput(opts) {
    opts = opts || {};
    var listeners = {};
    return {
      value: opts.value != null ? String(opts.value) : "",
      focusCalled: false,
      dataset: opts.noDataset ? null : {},
      placeholder: "",
      classList: { add: function () {}, remove: function () {} },
      focus: opts.noFocus
        ? undefined
        : function () {
            this.focusCalled = true;
          },
      addEventListener: function (type, fn) {
        if (!listeners[type]) listeners[type] = [];
        listeners[type].push(fn);
      },
      _dispatchInput: function () {
        var fns = listeners.input || [];
        for (var i = 0; i < fns.length; i++) fns[i]();
      }
    };
  }

  function buildCardDom(opts) {
    opts = opts || {};
    var timeline = {
      innerHTML: "",
      children: [],
      appendChild: function (n) {
        this.children.push(n);
      }
    };
    var chipsBox = {
      hidden: true,
      innerHTML: "",
      children: [],
      appendChild: function (c) {
        this.children.push(c);
      },
      querySelector: function () {
        return null;
      }
    };
    var a2uiChildren = [];
    var replyChildren = [];
    return {
      timeline: timeline,
      chipsBox: chipsBox,
      a2uiChildren: a2uiChildren,
      replyChildren: replyChildren,
      dom: {
        querySelector: function (sel) {
          if (sel === ".card-followup-chips") return chipsBox;
          if (sel === ".card-timeline") return timeline;
          if (sel === ".card-status-log") {
            return { innerHTML: "", appendChild: function () {}, querySelector: function () { return null; } };
          }
          if (sel === ".card-replies") {
            return {
              innerHTML: "",
              children: replyChildren,
              appendChild: function (c) {
                replyChildren.push(c);
              },
              querySelector: function () {
                return null;
              }
            };
          }
          if (sel === ".card-question") return { hidden: true, innerHTML: "" };
          if (sel === ".card-a2ui") {
            return {
              hidden: true,
              innerHTML: "",
              children: a2uiChildren,
              appendChild: function (c) {
                a2uiChildren.push(c);
              },
              querySelector: function () {
                return null;
              }
            };
          }
          return null;
        },
        querySelectorAll: function () {
          return [];
        },
        classList: { toggle: function () {}, contains: function () { return false; } }
      }
    };
  }

  function ensureDocument() {
    root.document = {
      createElement: function (tag) {
        var C = root.customElements && root.customElements.get ? root.customElements.get(tag) : null;
        return C
          ? new C()
          : {
              setAttribute: function () {},
              appendChild: function () {},
              removeAttribute: function () {},
              children: []
            };
      },
      getElementById: function () {
        return null;
      }
    };
  }

  function withCardInput(cardId, inputOpts, fn) {
    var mockInput = makeMockInput(inputOpts);
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
      },
      createElement: savedDoc && savedDoc.createElement ? savedDoc.createElement.bind(savedDoc) : function () {
        return { setAttribute: function () {}, appendChild: function () {} };
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

  function runPipeline(cardId, blocks, opts) {
    opts = opts || {};
    if (!root.PaletteCardRenderer || !PaletteCardRenderer.renderBlocks) {
      return { ok: false, error: "card_renderer_missing" };
    }
    ensureDocument();
    var mock = buildCardDom();
    var card = Object.assign(
      { id: cardId, expanded: true, uiState: "Done", pipelineBlocks: blocks },
      opts.card || {}
    );
    var logs = [];
    var renderOut = PaletteCardRenderer.renderBlocks(cardId, mock.dom, blocks, {
      debugLog: function (ev, det) {
        logs.push({ ev: ev, det: det });
      },
      deps: {
        esc: function (t) {
          return String(t || "");
        },
        getActionCard: function () {
          return card;
        },
        renderAgentPlainMarkdown: function (t) {
          return String(t || "");
        }
      }
    });
    var snap =
      root.PaletteSlotRenderTrace && PaletteSlotRenderTrace.snapshot
        ? PaletteSlotRenderTrace.snapshot(cardId)
        : {};
    return {
      ok: renderOut && renderOut.ok,
      snap: snap,
      logs: logs,
      card: card,
      mock: mock,
      renderOut: renderOut
    };
  }

  function isChipDisabled(compDisabled, action, pendingActionId) {
    return (
      !!compDisabled ||
      !!(action && action.disabled) ||
      !!(pendingActionId && action && action.id === pendingActionId)
    );
  }

  function sampleActionChipsBlock(id, actions) {
    return {
      id: id || "blk_ac_mvp",
      type: "a2ui",
      component: "ActionChips",
      state: "final",
      source: "system",
      confidence: 1,
      seq: 1,
      turnId: 1,
      traceId: "fx_mvp",
      props: { actions: actions || [] }
    };
  }

  __testOnly.installLitStub = installLitStub;
  __testOnly.makeMockInput = makeMockInput;
  __testOnly.buildCardDom = buildCardDom;
  __testOnly.withCardInput = withCardInput;
  __testOnly.runPipeline = runPipeline;
  __testOnly.isChipDisabled = isChipDisabled;
  __testOnly.sampleActionChipsBlock = sampleActionChipsBlock;
  __testOnly.ensureDocument = ensureDocument;

  root.PaletteActionChipsTestHelpers = {
    __testOnly: __testOnly
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
