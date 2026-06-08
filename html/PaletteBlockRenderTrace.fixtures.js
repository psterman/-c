/**
 * Palette block render trace / fallback fixtures
 */
(function (root) {
  var FIXTURES = {
    block_trace_render_error_isolated: {
      description: "Lit render_error 不影响同卡其它 block",
      cardId: "card-trace-err",
      blocks: [
        {
          id: "blk_plan_trace",
          type: "plan",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 1,
          turnId: 1,
          traceId: "fx_trace_err",
          items: [{ text: "计划步骤", state: "done" }]
        },
        {
          id: "blk_ac_trace_err",
          type: "a2ui",
          component: "ActionChips",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 2,
          turnId: 1,
          traceId: "fx_trace_err",
          props: {
            actions: [{ id: "ac_err", label: "错误 chip", intent: "prefill", payload: { text: "x" } }]
          }
        }
      ],
      forceLitRenderError: true
    },
    block_trace_invalid_schema: {
      description: "invalid ActionChips 记录 invalid_schema trace",
      cardId: "card-trace-invalid",
      blocks: [
        {
          id: "blk_ac_invalid",
          type: "a2ui",
          component: "ActionChips",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 1,
          turnId: 1,
          traceId: "fx_trace_invalid",
          props: { actions: [{ id: "bad", label: "" }] }
        }
      ]
    },
    block_trace_unknown_block: {
      description: "unknown a2ui block 记录 unknown_block trace",
      cardId: "card-trace-unknown",
      blocks: [
        {
          id: "blk_unknown",
          type: "a2ui",
          component: "UnknownWidget",
          state: "final",
          source: "heuristic",
          confidence: 0.5,
          seq: 1,
          turnId: 1,
          traceId: "fx_trace_unknown",
          props: {}
        }
      ]
    },
    block_trace_no_lit_component: {
      description: "无 Lit 组件时 ActionChips 记录 no_lit_component",
      cardId: "card-trace-nolit",
      blocks: [
        {
          id: "blk_ac_nolit",
          type: "a2ui",
          component: "ActionChips",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 1,
          turnId: 1,
          traceId: "fx_trace_nolit",
          props: {
            actions: [{ id: "n1", label: "无 Lit", intent: "prefill", payload: { text: "t" } }]
          }
        }
      ],
      hideLit: true
    },
    block_trace_snapshot_readable: {
      description: "snapshot 可区分 lit / legacy / fallback",
      cardId: "card-trace-snap",
      blocks: [
        {
          id: "blk_plan_snap",
          type: "plan",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 1,
          turnId: 1,
          traceId: "fx_trace_snap",
          items: [{ text: "步骤", state: "done" }]
        },
        {
          id: "blk_ac_snap",
          type: "a2ui",
          component: "ActionChips",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 2,
          turnId: 1,
          traceId: "fx_trace_snap",
          props: {
            actions: [{ id: "s1", label: "Snap", intent: "prefill", payload: { text: "s" } }]
          }
        },
        {
          id: "blk_unknown_snap",
          type: "a2ui",
          component: "GhostPanel",
          state: "final",
          source: "heuristic",
          confidence: 0.5,
          seq: 3,
          turnId: 1,
          traceId: "fx_trace_snap",
          props: {}
        }
      ],
      hideLit: true
    }
  };

  function installActionChipsStub(throwOnApply) {
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
    function Stub() {
      BaseEl.call(this);
      this.actions = [];
    }
    Stub.prototype = Object.create(BaseEl.prototype);
    root.HTMLElement = BaseEl;
    root.Lit = { LitElement: BaseEl, html: function () {} };
    root.customElements = {
      _registry: {},
      define: function (n, C) {
        this._registry[n] = C;
      },
      get: function (n) {
        return this._registry[n] || null;
      }
    };
    root.customElements.define("palette-action-chips", Stub);
    if (throwOnApply && root.PaletteCardSlots && PaletteCardSlots.COMPONENTS) {
      var def = PaletteCardSlots.COMPONENTS.ActionChips;
      if (def) {
        def.applyProps = function () {
          throw new Error("lit_render_fail_fixture");
        };
      }
    }
  }

  function buildMockDom() {
    var timeline = { innerHTML: "", children: [], appendChild: function (n) { this.children.push(n); } };
    var chipsBox = {
      hidden: true,
      innerHTML: "",
      children: [],
      appendChild: function (c) { this.children.push(c); },
      querySelector: function () { return null; }
    };
    return {
      timeline: timeline,
      dom: {
        querySelector: function (sel) {
          if (sel === ".card-followup-chips") return chipsBox;
          if (sel === ".card-timeline") return timeline;
          if (sel === ".card-status-log") return { innerHTML: "", appendChild: function () {}, querySelector: function () { return null; } };
          if (sel === ".card-replies") return { innerHTML: "", children: [], appendChild: function (c) { this.children.push(c); } };
          if (sel === ".card-question") return { hidden: true, innerHTML: "" };
          if (sel === ".card-a2ui") return { hidden: true, innerHTML: "", children: [], appendChild: function (c) { this.children.push(c); } };
          return null;
        },
        querySelectorAll: function () { return []; },
        classList: { toggle: function () {}, contains: function () { return false; } }
      }
    };
  }

  function runTraceFixture(name) {
    var fx = FIXTURES[name];
    if (!fx) return { ok: false, error: "unknown_trace_fixture:" + name, fixture: name };
    if (!root.PaletteCardRenderer || !PaletteCardRenderer.renderBlocks) {
      return { ok: false, error: "card_renderer_missing", fixture: name };
    }
    if (!root.PaletteSlotRenderTrace || !PaletteSlotRenderTrace.snapshot) {
      return { ok: false, error: "trace_missing", fixture: name };
    }

    var savedDoc = root.document;
    var savedGet = root.customElements && root.customElements.get;
    var savedApplyProps =
      root.PaletteCardSlots &&
      PaletteCardSlots.COMPONENTS &&
      PaletteCardSlots.COMPONENTS.ActionChips
        ? PaletteCardSlots.COMPONENTS.ActionChips.applyProps
        : null;

    if (fx.forceLitRenderError) installActionChipsStub(true);
    else if (!fx.hideLit) installActionChipsStub(false);

    if (fx.hideLit && root.customElements) {
      root.customElements.get = function () { return null; };
    }

    root.document = {
      createElement: function (tag) {
        var C = root.customElements && root.customElements.get ? root.customElements.get(tag) : null;
        return C ? new C() : { setAttribute: function () {}, appendChild: function () {}, removeAttribute: function () {} };
      },
      getElementById: function () { return null; }
    };

    var mock = buildMockDom();
    var card = { id: fx.cardId, expanded: true, uiState: "Done", pipelineBlocks: fx.blocks };
    var logs = [];
    var out = PaletteCardRenderer.renderBlocks(fx.cardId, mock.dom, fx.blocks, {
      debugLog: function (ev, det) { logs.push({ ev: ev, det: det }); },
      deps: {
        esc: function (t) { return String(t || ""); },
        getActionCard: function () { return card; },
        renderAgentPlainMarkdown: function (t) { return String(t || ""); }
      }
    });
    var snap = PaletteSlotRenderTrace.snapshot(fx.cardId);
    var traceLogs = logs.filter(function (l) { return l.ev === "block_render_trace"; });

    if (savedApplyProps && root.PaletteCardSlots && root.PaletteCardSlots.COMPONENTS) {
      root.PaletteCardSlots.COMPONENTS.ActionChips.applyProps = savedApplyProps;
    }
    if (savedGet && root.customElements) root.customElements.get = savedGet;
    if (savedDoc !== undefined) root.document = savedDoc;
    else delete root.document;

    var reasons = root.PaletteSlotRenderTrace.TRACE_REASONS || {};

    if (name === "block_trace_render_error_isolated") {
      var acRow = PaletteSlotRenderTrace.findBlock(fx.cardId, "blk_ac_trace_err");
      return {
        fixture: name,
        ok:
          out &&
          out.ok &&
          mock.timeline.children.length === 1 &&
          !!acRow &&
          acRow.renderer === "legacy" &&
          acRow.reason === (reasons.RENDER_ERROR || "render_error") &&
          traceLogs.some(function (l) {
            try {
              var d = JSON.parse(l.det);
              return d.blockId === "blk_ac_trace_err" && d.reason === (reasons.RENDER_ERROR || "render_error");
            } catch (_) {
              return false;
            }
          })
      };
    }

    if (name === "block_trace_invalid_schema") {
      var invalidRow = snap.ActionChips;
      return {
        fixture: name,
        ok:
          out &&
          out.ok &&
          !!invalidRow &&
          invalidRow.renderer === "fallback" &&
          invalidRow.reason === (reasons.INVALID_SCHEMA || "invalid_schema") &&
          traceLogs.some(function (l) {
            try {
              return JSON.parse(l.det).reason === (reasons.INVALID_SCHEMA || "invalid_schema");
            } catch (_) {
              return false;
            }
          })
      };
    }

    if (name === "block_trace_unknown_block") {
      var unknownRow = snap.a2ui;
      return {
        fixture: name,
        ok:
          out &&
          out.ok &&
          !!unknownRow &&
          unknownRow.renderer === "fallback" &&
          unknownRow.reason === (reasons.UNKNOWN_BLOCK || "unknown_block")
      };
    }

    if (name === "block_trace_no_lit_component") {
      var nolitRow = snap.ActionChips;
      return {
        fixture: name,
        ok:
          out &&
          out.ok &&
          !!nolitRow &&
          nolitRow.renderer === "legacy" &&
          nolitRow.reason === (reasons.NO_LIT_COMPONENT || "no_lit_component")
      };
    }

    if (name === "block_trace_snapshot_readable") {
      var blocks = snap.blocks || [];
      var planRow = blocks.find(function (b) { return b.blockId === "blk_plan_snap"; });
      var acSnapRow = blocks.find(function (b) { return b.blockId === "blk_ac_snap"; });
      var ghostRow = blocks.find(function (b) { return b.blockId === "blk_unknown_snap"; });
      return {
        fixture: name,
        ok:
          out &&
          out.ok &&
          blocks.length >= 3 &&
          !!planRow &&
          planRow.renderer === "legacy" &&
          planRow.reason === (reasons.NO_LIT_COMPONENT || "no_lit_component") &&
          !!acSnapRow &&
          acSnapRow.renderer === "legacy" &&
          acSnapRow.reason === (reasons.NO_LIT_COMPONENT || "no_lit_component") &&
          !!ghostRow &&
          ghostRow.renderer === "fallback" &&
          ghostRow.reason === (reasons.UNKNOWN_BLOCK || "unknown_block") &&
          !!snap.ActionChips &&
          !!snap.plan
      };
    }

    return { ok: false, error: "unhandled_trace_fixture", fixture: name };
  }

  function runAllTraceFixtures() {
    var names = Object.keys(FIXTURES);
    var results = [];
    var passed = 0;
    var failed = 0;
    for (var i = 0; i < names.length; i++) {
      var out = runTraceFixture(names[i]);
      out.fixture = names[i];
      results.push(out);
      if (out.ok) passed++;
      else failed++;
    }
    return { ok: failed === 0, passed: passed, failed: failed, results: results };
  }

  root.PaletteBlockRenderTraceFixtures = {
    FIXTURES: FIXTURES,
    runTraceFixture: runTraceFixture,
    runAllTraceFixtures: runAllTraceFixtures
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
