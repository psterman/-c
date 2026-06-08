/**
 * Palette ActionChips adapter fixtures
 */
(function (root) {
  var FIXTURES = {
    action_chips_normalize_legacy: {
      description: "followUpChips + reply.actions 规范化为 ActionChips a2ui block",
      replyActions: [
        { id: "reply_chip", label: "补充说明", kind: "safe", intent: "append", prefill: "请补充说明：" }
      ],
      followUpChips: [
        {
          id: "route_chip",
          label: "对比维度",
          kind: "safe",
          intent: "append",
          prefill: "请补充更多对比维度："
        }
      ]
    },
    action_chips_empty: {
      description: "空输入返回 null 并记录 action_chips_empty",
      replyActions: [],
      followUpChips: []
    },
    action_chips_skip_no_label: {
      description: "缺少 label 的 action 跳过并记录 action_chips_invalid_action",
      replyActions: [
        { id: "bad", kind: "safe" },
        { id: "good", label: "有效", prefill: "有效文本" }
      ]
    },
    action_chips_default_intent: {
      description: "缺少 intent 默认映射为 prefill",
      replyActions: [{ id: "a1", label: "默认意图" }]
    },
    action_chips_payload_text: {
      description: "payload.text 优先级 text > prompt > prefill > label",
      replyActions: [
        { id: "t1", label: "L1", text: "来自 text" },
        { id: "t2", label: "L2", prompt: "来自 prompt" },
        { id: "t3", label: "L3", prefill: "来自 prefill" },
        { id: "t4", label: "L4" }
      ]
    },
    action_chips_schema_roundtrip: {
      description: "ActionChips block 经 PaletteBlockSchema.validateBlocks 往返",
      block: {
        type: "a2ui",
        component: "ActionChips",
        id: "blk_ac_test",
        state: "final",
        source: "system",
        confidence: 1,
        seq: 9,
        turnId: 1,
        traceId: "fx_ac",
        props: {
          actions: [
            { id: "c1", label: "提交", intent: "submit", payload: { text: "执行提交" }, tone: "primary" }
          ]
        }
      }
    },
    action_chips_pipeline_valid: {
      description: "有效 ActionChips block 进入 pipeline 并被识别为 legacy fallback",
      blocks: [
        {
          id: "blk_ac_pipe",
          type: "a2ui",
          component: "ActionChips",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 2,
          turnId: 1,
          traceId: "fx_pipe",
          props: {
            actions: [{ id: "p1", label: "继续补充", intent: "prefill", payload: { text: "请补充" } }]
          }
        }
      ]
    },
    action_chips_pipeline_fallback_legacy: {
      description: "无 Lit 组件时 ActionChips fallback，resolveFollowUpChips 可读 pipeline actions",
      blocks: [
        {
          id: "blk_ac_fb",
          type: "a2ui",
          component: "ActionChips",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 1,
          turnId: 1,
          traceId: "fx_fb",
          props: {
            actions: [{ id: "fb1", label: "Fallback chip", intent: "prefill", payload: { text: "fallback text" } }]
          }
        }
      ]
    },
    action_chips_pipeline_invalid_card_ok: {
      description: "invalid ActionChips 不影响同卡其它 block 渲染",
      blocks: [
        {
          id: "blk_plan",
          type: "plan",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 1,
          turnId: 1,
          traceId: "fx_mix",
          items: [{ text: "步骤一", state: "done" }]
        },
        {
          id: "blk_ac_bad",
          type: "a2ui",
          component: "ActionChips",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 2,
          turnId: 1,
          traceId: "fx_mix",
          props: { actions: [] }
        },
        {
          id: "blk_reply",
          type: "reply",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 3,
          turnId: 1,
          traceId: "fx_mix",
          markdown: "回复正文保留"
        }
      ]
    }
  };

  function makePipelineMockDom() {
    var a2uiChildren = [];
    var replyChildren = [];
    var timeline = { innerHTML: "", children: [], appendChild: function (n) { this.children.push(n); } };
    var statusLog = { innerHTML: "", scrollTop: 0, appendChild: function () {}, querySelector: function () { return null; } };
    var a2ui = {
      hidden: true,
      innerHTML: "",
      children: a2uiChildren,
      appendChild: function (n) {
        a2uiChildren.push(n);
      },
      querySelector: function () {
        return null;
      }
    };
    var replies = {
      innerHTML: "",
      children: replyChildren,
      appendChild: function (n) {
        replyChildren.push(n);
      },
      querySelector: function () {
        return null;
      }
    };
    return {
      a2uiChildren: a2uiChildren,
      replyChildren: replyChildren,
      timelineChildren: timeline.children,
      dom: {
        querySelector: function (sel) {
          if (sel === ".card-a2ui") return a2ui;
          if (sel === ".card-replies") return replies;
          if (sel === ".card-timeline") return timeline;
          if (sel === ".card-status-log") return statusLog;
          if (sel === ".card-question") return { hidden: true, innerHTML: "" };
          if (sel === ".card-followup-chips") {
            return {
              hidden: true,
              innerHTML: "",
              children: [],
              appendChild: function () {},
              querySelector: function () { return null; }
            };
          }
          if (sel === ".card-reply") return null;
          return null;
        },
        querySelectorAll: function (sel) {
          if (sel === ".card-a2ui .a2ui-slot") return a2uiChildren;
          return [];
        },
        classList: { toggle: function () {}, contains: function () { return false; } }
      }
    };
  }

  function ensurePipelineDocument() {
    if (root.document && root.document.createElement) return;
    root.document = {
      createElement: function (tag) {
        var el = {
          tagName: tag,
          className: "",
          innerHTML: "",
          hidden: false,
          textContent: "",
          children: [],
          setAttribute: function () {},
          appendChild: function (n) {
            this.children.push(n);
          },
          insertBefore: function () {},
          replaceChild: function () {}
        };
        return el;
      }
    };
  }

  function runPipelineFixture(fx) {
    if (!root.PaletteCardRenderer || !PaletteCardRenderer.renderBlocks) {
      return { ok: false, error: "card_renderer_missing" };
    }
    ensurePipelineDocument();
    if (!root.PaletteSlotRenderTrace || !PaletteSlotRenderTrace.snapshot) {
      return { ok: false, error: "slot_trace_missing" };
    }
    var mock = makePipelineMockDom();
    var card = {
      id: "card-pipe-fixture",
      expanded: true,
      uiState: "Done",
      pipelineBlocks: fx.blocks
    };
    var logs = [];
    PaletteCardRenderer.renderBlocks("card-pipe-fixture", mock.dom, fx.blocks, {
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
    return {
      snap: PaletteSlotRenderTrace.snapshot("card-pipe-fixture"),
      logs: logs,
      a2uiSlotCount: mock.a2uiChildren.length,
      replyCount: mock.replyChildren.length,
      timelineCount: mock.timelineChildren.length,
      card: card
    };
  }

  function runActionChipsFixture(name) {
    var fx = FIXTURES[name];
    if (!fx) return { ok: false, error: "unknown_action_chips_fixture:" + name, fixture: name };
    if (!root.PaletteActionChipsAdapter || !PaletteActionChipsAdapter.normalizeFollowUpActionsToActionChips) {
      return { ok: false, error: "adapter_missing", fixture: name };
    }

    var logs = [];
    var context = {
      cardId: "card-ac-fixture",
      followUpChips: fx.followUpChips || [],
      debugLog: function (ev, det) {
        logs.push({ ev: ev, det: det });
      }
    };
    var out = { fixture: name, description: fx.description || "", logs: logs, ok: true };

    if (
      name === "action_chips_pipeline_valid" ||
      name === "action_chips_pipeline_fallback_legacy" ||
      name === "action_chips_pipeline_invalid_card_ok"
    ) {
      var pipe = runPipelineFixture(fx);
      out.pipeline = pipe;
      if (!pipe || pipe.ok === false) {
        out.ok = false;
        out.error = (pipe && pipe.error) || "pipeline_failed";
        return out;
      }

      if (name === "action_chips_pipeline_valid") {
        var acSnap = pipe.snap && pipe.snap.ActionChips;
        out.ok =
          !!acSnap &&
          acSnap.renderer === "legacy" &&
          acSnap.reason === "no_lit_component" &&
          acSnap.blockType === "ActionChips" &&
          acSnap.count === 1 &&
          pipe.a2uiSlotCount === 0 &&
          pipe.logs.some(function (l) {
            return l.ev === "action_chips_render";
          });
        return out;
      }

      if (name === "action_chips_pipeline_fallback_legacy") {
        var chips =
          root.PaletteActionBinder &&
          PaletteActionBinder.getPipelineActionChips &&
          PaletteActionBinder.getPipelineActionChips(pipe.card);
        out.chips = chips;
        out.ok =
          chips &&
          chips.length === 1 &&
          chips[0].id === "fb1" &&
          chips[0].prefill === "fallback text" &&
          pipe.snap &&
          pipe.snap.ActionChips &&
          pipe.snap.ActionChips.renderer === "legacy";
        return out;
      }

      if (name === "action_chips_pipeline_invalid_card_ok") {
        var invalidSnap = pipe.snap && pipe.snap.ActionChips;
        out.ok =
          pipe.timelineCount === 1 &&
          pipe.replyCount === 1 &&
          pipe.a2uiSlotCount === 0 &&
          !!invalidSnap &&
          invalidSnap.renderer === "fallback" &&
          invalidSnap.reason === "invalid_schema";
        return out;
      }
    }

    if (name === "action_chips_schema_roundtrip") {
      if (!root.PaletteBlockSchema || !PaletteBlockSchema.validateBlocks) {
        return { ok: false, error: "schema_missing", fixture: name };
      }
      var vr = PaletteBlockSchema.validateBlocks([fx.block]);
      out.validate = vr;
      out.ok =
        vr.blocks &&
        vr.blocks.length === 1 &&
        vr.blocks[0].component === "ActionChips" &&
        vr.blocks[0].props.actions.length === 1 &&
        vr.blocks[0].props.actions[0].intent === "submit";
      return out;
    }

    var block = PaletteActionChipsAdapter.normalizeFollowUpActionsToActionChips(fx.replyActions || [], context);
    out.block = block;

    if (name === "action_chips_normalize_legacy") {
      out.ok =
        !!block &&
        block.type === "a2ui" &&
        block.component === "ActionChips" &&
        block.props.actions.length === 2;
      var created = logs.some(function (l) {
        return l.ev === "action_chips_block_created";
      });
      if (!created) out.ok = false;
      return out;
    }

    if (name === "action_chips_empty") {
      out.ok = block === null && logs.some(function (l) { return l.ev === "action_chips_empty"; });
      return out;
    }

    if (name === "action_chips_skip_no_label") {
      out.ok =
        !!block &&
        block.props.actions.length === 1 &&
        block.props.actions[0].id === "good" &&
        logs.some(function (l) { return l.ev === "action_chips_invalid_action"; });
      return out;
    }

    if (name === "action_chips_default_intent") {
      out.ok = !!block && block.props.actions[0].intent === "prefill";
      return out;
    }

    if (name === "action_chips_payload_text") {
      if (!block || block.props.actions.length !== 4) {
        out.ok = false;
        return out;
      }
      var acts = block.props.actions;
      out.ok =
        acts[0].payload.text === "来自 text" &&
        acts[1].payload.text === "来自 prompt" &&
        acts[2].payload.text === "来自 prefill" &&
        acts[3].payload.text === "L4";
      return out;
    }

    out.ok = false;
    out.error = "unhandled_fixture";
    return out;
  }

  function runAllActionChipsFixtures() {
    var names = Object.keys(FIXTURES);
    var results = [];
    var passed = 0;
    var failed = 0;
    for (var i = 0; i < names.length; i++) {
      var out = runActionChipsFixture(names[i]);
      results.push(out);
      if (out.ok) passed++;
      else failed++;
    }
    return { ok: failed === 0, passed: passed, failed: failed, results: results };
  }

  root.PaletteActionChipsFixtures = {
    FIXTURES: FIXTURES,
    runActionChipsFixture: runActionChipsFixture,
    runAllActionChipsFixtures: runAllActionChipsFixtures
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
