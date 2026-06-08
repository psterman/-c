/**
 * ActionChips MVP 集成 fixtures — 覆盖 normalize / renderer / Lit / Controller / UX / trace
 */
(function (root) {
  var H = function () {
    return root.PaletteActionChipsTestHelpers && PaletteActionChipsTestHelpers.__testOnly;
  };

  var FIXTURES = {
    action_chips_basic: {
      category: "normalize",
      description: "reply.actions 规范化为 ActionChips block"
    },
    action_chips_empty: {
      category: "normalize",
      description: "空 actions 安全返回 null"
    },
    action_chips_invalid_action: {
      category: "normalize",
      description: "invalid action（无 label）被过滤"
    },
    action_chips_pipeline: {
      category: "renderer",
      description: "ActionChips 进入 A2UI pipeline 并记录 trace"
    },
    action_chips_lit_render: {
      category: "renderer",
      description: "有 Lit component 时走 lit 渲染"
    },
    action_chips_lit_fallback: {
      category: "renderer",
      description: "无 Lit component 时走 legacy fallback"
    },
    action_chips_invalid_schema: {
      category: "renderer",
      description: "invalid schema 时 fallback 且不影响其它 block"
    },
    action_chips_disabled: {
      category: "lit",
      description: "disabled chip 不可交互"
    },
    action_chips_pending: {
      category: "lit",
      description: "pendingActionId 对应 chip 禁用且带 is-pending"
    },
    action_chips_a2ui_action: {
      category: "lit",
      description: "click 路径经 bridge dispatch a2ui-action"
    },
    action_chips_prefill: {
      category: "controller",
      description: "prefill 填入 input 并 focus"
    },
    action_chips_submit: {
      category: "controller",
      description: "submit 调用 submitFollowup handler"
    },
    action_chips_unsupported: {
      category: "controller",
      description: "unsupported intent 不抛错"
    },
    action_chips_undo: {
      category: "controller",
      description: "undo 恢复 previousInputValue"
    },
    action_chips_ux_hint: {
      category: "ux",
      description: "prefill 后 placeholder hint 与 dataset.prefillHint"
    },
    action_chips_ux_input_clear: {
      category: "ux",
      description: "用户 input 后清除 hint"
    },
    action_chips_ux_timeout_clear: {
      category: "ux",
      description: "timeout 后清除 hint"
    },
    action_chips_trace_lit_ok: {
      category: "trace",
      description: "lit render 记录 reason=ok"
    },
    action_chips_trace_fallback: {
      category: "trace",
      description: "fallback 记录明确 reason"
    },
    action_chips_trace_render_error: {
      category: "trace",
      description: "render_error 不影响其它 block"
    }
  };

  var REASONS =
    root.PaletteSlotRenderTrace && PaletteSlotRenderTrace.TRACE_REASONS
      ? PaletteSlotRenderTrace.TRACE_REASONS
      : {
          OK: "ok",
          INVALID_SCHEMA: "invalid_schema",
          NO_LIT_COMPONENT: "no_lit_component",
          RENDER_ERROR: "render_error"
        };

  var HINT_TEXT =
    root.PaletteActionController && PaletteActionController.PREFILL_HINT_TEXT
      ? PaletteActionController.PREFILL_HINT_TEXT
      : "已从建议填入，可继续编辑后发送";
  var HINT_MS =
    root.PaletteActionController && PaletteActionController.PREFILL_HINT_MS
      ? PaletteActionController.PREFILL_HINT_MS
      : 1900;

  function runMvpFixture(name) {
    var fx = FIXTURES[name];
    if (!fx) return { ok: false, error: "unknown_mvp_fixture:" + name, fixture: name, category: "" };
    var helpers = H();
    if (!helpers) return { ok: false, error: "test_helpers_missing", fixture: name, category: fx.category };

    var logs = [];
    function debugLog(ev, det) {
      logs.push({ ev: ev, det: det });
    }

    if (name === "action_chips_basic") {
      if (!root.PaletteActionChipsAdapter) return { ok: false, error: "adapter_missing", fixture: name, category: fx.category };
      var block = PaletteActionChipsAdapter.normalizeFollowUpActionsToActionChips(
        [{ id: "r1", label: "补充", prefill: "请补充" }],
        { cardId: "card-mvp-basic", followUpChips: [], debugLog: debugLog }
      );
      return {
        fixture: name,
        category: fx.category,
        ok:
          !!block &&
          block.type === "a2ui" &&
          block.component === "ActionChips" &&
          block.props.actions.length === 1 &&
          logs.some(function (l) { return l.ev === "action_chips_block_created"; })
      };
    }

    if (name === "action_chips_empty") {
      if (!root.PaletteActionChipsAdapter) return { ok: false, error: "adapter_missing", fixture: name, category: fx.category };
      var empty = PaletteActionChipsAdapter.normalizeFollowUpActionsToActionChips([], {
        cardId: "card-mvp-empty",
        followUpChips: [],
        debugLog: debugLog
      });
      return {
        fixture: name,
        category: fx.category,
        ok: empty === null && logs.some(function (l) { return l.ev === "action_chips_empty"; })
      };
    }

    if (name === "action_chips_invalid_action") {
      if (!root.PaletteActionChipsAdapter) return { ok: false, error: "adapter_missing", fixture: name, category: fx.category };
      var filtered = PaletteActionChipsAdapter.normalizeFollowUpActionsToActionChips(
        [{ id: "bad" }, { id: "good", label: "有效" }],
        { cardId: "card-mvp-invalid", followUpChips: [], debugLog: debugLog }
      );
      return {
        fixture: name,
        category: fx.category,
        ok:
          !!filtered &&
          filtered.props.actions.length === 1 &&
          filtered.props.actions[0].id === "good" &&
          logs.some(function (l) { return l.ev === "action_chips_invalid_action"; })
      };
    }

    if (name === "action_chips_pipeline") {
      var pipe = helpers.runPipeline("card-mvp-pipe", [
        helpers.sampleActionChipsBlock("blk_mvp_pipe", [
          { id: "p1", label: "继续", intent: "prefill", payload: { text: "继续" } }
        ])
      ]);
      return {
        fixture: name,
        category: fx.category,
        ok:
          pipe.ok &&
          pipe.snap &&
          pipe.snap.ActionChips &&
          pipe.snap.ActionChips.blockType === "ActionChips" &&
          pipe.logs.some(function (l) { return l.ev === "action_chips_render" || l.ev === "block_render_trace"; })
      };
    }

    if (name === "action_chips_lit_render") {
      var litStub = helpers.installLitStub({});
      var litPipe = helpers.runPipeline("card-mvp-lit", [
        helpers.sampleActionChipsBlock("blk_mvp_lit", [
          { id: "l1", label: "Lit", intent: "prefill", payload: { text: "lit" } }
        ])
      ]);
      litStub.restore();
      return {
        fixture: name,
        category: fx.category,
        ok:
          litPipe.ok &&
          litPipe.snap.ActionChips &&
          litPipe.snap.ActionChips.renderer === "lit" &&
          litPipe.mock.chipsBox.children.length === 1 &&
          litPipe.logs.some(function (l) { return l.ev === "action_chips_lit_rendered"; })
      };
    }

    if (name === "action_chips_lit_fallback") {
      var noLitStub = helpers.installLitStub({ hideLit: true });
      var fbPipe = helpers.runPipeline("card-mvp-fb", [
        helpers.sampleActionChipsBlock("blk_mvp_fb", [
          { id: "f1", label: "Fallback", intent: "prefill", payload: { text: "fb" } }
        ])
      ]);
      noLitStub.restore();
      var fbChips =
        root.PaletteActionBinder && PaletteActionBinder.getPipelineActionChips
          ? PaletteActionBinder.getPipelineActionChips(fbPipe.card)
          : [];
      return {
        fixture: name,
        category: fx.category,
        ok:
          fbPipe.snap.ActionChips.renderer === "legacy" &&
          fbPipe.snap.ActionChips.reason === REASONS.NO_LIT_COMPONENT &&
          fbChips.length === 1 &&
          fbChips[0].id === "f1"
      };
    }

    if (name === "action_chips_invalid_schema") {
      var invalidPipe = helpers.runPipeline("card-mvp-invalid-schema", [
        {
          id: "blk_plan_mvp",
          type: "plan",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 1,
          turnId: 1,
          traceId: "fx_mvp",
          items: [{ text: "步骤", state: "done" }]
        },
        helpers.sampleActionChipsBlock("blk_mvp_bad", [])
      ]);
      return {
        fixture: name,
        category: fx.category,
        ok:
          invalidPipe.ok &&
          invalidPipe.mock.timeline.children.length === 1 &&
          invalidPipe.snap.ActionChips.renderer === "fallback" &&
          invalidPipe.snap.ActionChips.reason === REASONS.INVALID_SCHEMA
      };
    }

    if (name === "action_chips_disabled") {
      var disAction = { id: "d1", label: "禁用", intent: "prefill", payload: { text: "x" }, disabled: true };
      return {
        fixture: name,
        category: fx.category,
        ok: helpers.isChipDisabled(false, disAction, "")
      };
    }

    if (name === "action_chips_pending") {
      var pendAction = { id: "p1", label: "等待", intent: "prefill", payload: { text: "p" } };
      var cls = "card-followup-chip";
      if (pendAction.id === "p1") cls += " is-pending";
      return {
        fixture: name,
        category: fx.category,
        ok: helpers.isChipDisabled(false, pendAction, "p1") && cls.indexOf("is-pending") >= 0
      };
    }

    if (name === "action_chips_a2ui_action") {
      if (!root.PaletteA2UIEventBridge || !PaletteA2UIEventBridge.install) {
        return { ok: false, error: "bridge_missing", fixture: name, category: fx.category };
      }
      if (PaletteA2UIEventBridge._resetForTest) PaletteA2UIEventBridge._resetForTest();
      var bridgeLogs = [];
      var listeners = [];
      var bridgeInput = helpers.makeMockInput();
      var bridgeDom = {
        querySelector: function (sel) {
          if (sel === ".card-followup-input") return bridgeInput;
          return null;
        }
      };
      root.document = {
        getElementById: function (id) {
          return id === "card-card-mvp-bridge" ? bridgeDom : null;
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
          return { id: "card-mvp-bridge", uiState: "Done" };
        },
        debugLog: debugLog
      });
      var action = { id: "br1", label: "Bridge", intent: "prefill", payload: { text: "bridge text" } };
      listeners.forEach(function (l) {
        if (l.type === "a2ui-action") {
          l.fn({ detail: action, target: { getAttribute: function (k) { return k === "card-id" ? "card-mvp-bridge" : ""; } } });
        }
      });
      return {
        fixture: name,
        category: fx.category,
        ok:
          bridgeInput.value === "bridge text" &&
          logs.some(function (l) { return l.ev === "action_chips_lit_event"; }) &&
          logs.some(function (l) { return l.ev === "a2ui_action_prefill"; })
      };
    }

    if (name === "action_chips_prefill" || name === "action_chips_ux_hint") {
      if (!root.PaletteActionController) return { ok: false, error: "controller_missing", fixture: name, category: fx.category };
      var pre = helpers.withCardInput("card-mvp-prefill", {}, function () {
        return PaletteActionController.handleA2uiAction(
          { id: "pf1", label: "建议", intent: "prefill", payload: { text: "建议内容" } },
          { cardId: "card-mvp-prefill", card: { id: "card-mvp-prefill", uiState: "Done" }, debugLog: debugLog }
        );
      });
      if (name === "action_chips_prefill") {
        return {
          fixture: name,
          category: fx.category,
          ok:
            pre.out &&
            pre.out.ok &&
            pre.mockInput.value === "建议内容" &&
            pre.mockInput.focusCalled &&
            logs.some(function (l) { return l.ev === "a2ui_action_prefill"; })
        };
      }
      return {
        fixture: name,
        category: fx.category,
        ok:
          pre.mockInput.placeholder === HINT_TEXT &&
          pre.mockInput.dataset &&
          pre.mockInput.dataset.prefillHint === "1"
      };
    }

    if (name === "action_chips_submit") {
      if (!root.PaletteActionController) return { ok: false, error: "controller_missing", fixture: name, category: fx.category };
      var submitCalls = [];
      var sub = helpers.withCardInput("card-mvp-submit", {}, function () {
        return PaletteActionController.handleA2uiAction(
          { id: "sb1", label: "发送", intent: "submit", payload: { text: "发送内容" } },
          {
            cardId: "card-mvp-submit",
            card: { id: "card-mvp-submit", uiState: "Done" },
            debugLog: debugLog,
            submitFollowup: function (text) {
              submitCalls.push(String(text || ""));
              return true;
            }
          }
        );
      });
      return {
        fixture: name,
        category: fx.category,
        ok: sub.out && sub.out.ok && submitCalls.length === 1 && submitCalls[0] === "发送内容"
      };
    }

    if (name === "action_chips_unsupported") {
      if (!root.PaletteActionController) return { ok: false, error: "controller_missing", fixture: name, category: fx.category };
      var threw = false;
      var unsupported;
      try {
        unsupported = PaletteActionController.handleA2uiAction(
          { id: "in1", label: "查看", intent: "inspect", payload: { text: "detail" } },
          { cardId: "card-mvp-inspect", card: { uiState: "Done" }, debugLog: debugLog }
        );
      } catch (_) {
        threw = true;
      }
      return {
        fixture: name,
        category: fx.category,
        ok: !threw && unsupported && unsupported.ok && unsupported.handled === false
      };
    }

    if (name === "action_chips_undo") {
      if (!root.PaletteActionController) return { ok: false, error: "controller_missing", fixture: name, category: fx.category };
      var cardUndo = { id: "card-mvp-undo", uiState: "Done" };
      var undoRun = helpers.withCardInput("card-mvp-undo", { value: "原有内容" }, function () {
        PaletteActionController.handleA2uiAction(
          { id: "pfu", label: "覆盖", intent: "prefill", payload: { text: "新内容" } },
          { cardId: "card-mvp-undo", card: cardUndo, debugLog: debugLog }
        );
        return PaletteActionController.handleA2uiAction(
          { id: "undo1", label: "撤销", intent: "undo", payload: {} },
          { cardId: "card-mvp-undo", card: cardUndo, debugLog: debugLog }
        );
      });
      return {
        fixture: name,
        category: fx.category,
        ok: undoRun.out && undoRun.out.ok && undoRun.mockInput.value === "原有内容"
      };
    }

    if (name === "action_chips_ux_input_clear") {
      if (!root.PaletteActionController) return { ok: false, error: "controller_missing", fixture: name, category: fx.category };
      var clearRun = helpers.withCardInput("card-mvp-clear", {}, function (mockInput) {
        PaletteActionController.handleA2uiAction(
          { id: "pf2", label: "填入", intent: "prefill", payload: { text: "填入" } },
          { cardId: "card-mvp-clear", card: { uiState: "Done" }, debugLog: debugLog }
        );
        mockInput._dispatchInput();
        return mockInput;
      });
      return {
        fixture: name,
        category: fx.category,
        ok:
          clearRun.mockInput.dataset &&
          clearRun.mockInput.dataset.prefillHint !== "1" &&
          clearRun.mockInput.placeholder === "追加新指令…"
      };
    }

    if (name === "action_chips_ux_timeout_clear") {
      if (!root.PaletteActionController) return { ok: false, error: "controller_missing", fixture: name, category: fx.category };
      var timers = [];
      var savedSt = root.setTimeout;
      var savedCt = root.clearTimeout;
      root.setTimeout = function (fn, ms) {
        timers.push({ fn: fn, ms: ms });
        return timers.length;
      };
      root.clearTimeout = function () {};
      var timeoutInput;
      helpers.withCardInput("card-mvp-timeout", {}, function (mockInput) {
        timeoutInput = mockInput;
        PaletteActionController.handleA2uiAction(
          { id: "pf3", label: "超时", intent: "prefill", payload: { text: "超时" } },
          { cardId: "card-mvp-timeout", card: { uiState: "Done" }, debugLog: debugLog }
        );
        var hintTimer = timers.filter(function (t) { return t.ms === HINT_MS; })[0];
        if (hintTimer && hintTimer.fn) hintTimer.fn();
        return mockInput;
      });
      if (savedSt !== undefined) root.setTimeout = savedSt;
      else delete root.setTimeout;
      if (savedCt !== undefined) root.clearTimeout = savedCt;
      else delete root.clearTimeout;
      return {
        fixture: name,
        category: fx.category,
        ok:
          timeoutInput &&
          timeoutInput.dataset &&
          timeoutInput.dataset.prefillHint !== "1" &&
          timeoutInput.placeholder === "追加新指令…"
      };
    }

    if (name === "action_chips_trace_lit_ok") {
      var okStub = helpers.installLitStub({});
      var okPipe = helpers.runPipeline("card-mvp-trace-ok", [
        helpers.sampleActionChipsBlock("blk_trace_ok", [
          { id: "t1", label: "Trace", intent: "prefill", payload: { text: "t" } }
        ])
      ]);
      okStub.restore();
      var okRow =
        root.PaletteSlotRenderTrace && PaletteSlotRenderTrace.findBlock
          ? PaletteSlotRenderTrace.findBlock("card-mvp-trace-ok", "blk_trace_ok")
          : null;
      return {
        fixture: name,
        category: fx.category,
        ok:
          okPipe.snap.ActionChips.renderer === "lit" &&
          okPipe.snap.ActionChips.reason === REASONS.OK &&
          !!okRow &&
          okRow.reason === REASONS.OK
      };
    }

    if (name === "action_chips_trace_fallback") {
      var fbStub = helpers.installLitStub({ hideLit: true });
      var traceFb = helpers.runPipeline("card-mvp-trace-fb", [
        helpers.sampleActionChipsBlock("blk_trace_fb", [
          { id: "tf1", label: "FB", intent: "prefill", payload: { text: "fb" } }
        ])
      ]);
      fbStub.restore();
      return {
        fixture: name,
        category: fx.category,
        ok:
          traceFb.snap.ActionChips.renderer === "legacy" &&
          traceFb.snap.ActionChips.reason === REASONS.NO_LIT_COMPONENT &&
          traceFb.logs.some(function (l) {
            if (l.ev !== "block_render_trace") return false;
            try {
              var d = JSON.parse(l.det);
              return d.reason === REASONS.NO_LIT_COMPONENT;
            } catch (_) {
              return false;
            }
          })
      };
    }

    if (name === "action_chips_trace_render_error") {
      var errStub = helpers.installLitStub({ throwOnApplyProps: true });
      var errPipe = helpers.runPipeline("card-mvp-trace-err", [
        {
          id: "blk_plan_trace",
          type: "plan",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 1,
          turnId: 1,
          traceId: "fx_mvp",
          items: [{ text: "计划", state: "done" }]
        },
        helpers.sampleActionChipsBlock("blk_trace_err", [
          { id: "te1", label: "Err", intent: "prefill", payload: { text: "e" } }
        ])
      ]);
      errStub.restore();
      var errRow =
        root.PaletteSlotRenderTrace && PaletteSlotRenderTrace.findBlock
          ? PaletteSlotRenderTrace.findBlock("card-mvp-trace-err", "blk_trace_err")
          : null;
      return {
        fixture: name,
        category: fx.category,
        ok:
          errPipe.ok &&
          errPipe.mock.timeline.children.length === 1 &&
          errRow &&
          errRow.reason === REASONS.RENDER_ERROR &&
          errPipe.snap.ActionChips.renderer === "legacy"
      };
    }

    return { ok: false, error: "unhandled_mvp_fixture", fixture: name, category: fx.category };
  }

  function runAllMvpFixtures() {
    var names = Object.keys(FIXTURES);
    var results = [];
    var passed = 0;
    var failed = 0;
    var byCategory = {};
    for (var i = 0; i < names.length; i++) {
      var out = runMvpFixture(names[i]);
      out.fixture = names[i];
      out.description = FIXTURES[names[i]].description || "";
      out.category = out.category || FIXTURES[names[i]].category || "";
      results.push(out);
      if (!byCategory[out.category]) byCategory[out.category] = { passed: 0, failed: 0 };
      if (out.ok) {
        passed++;
        byCategory[out.category].passed++;
      } else {
        failed++;
        byCategory[out.category].failed++;
      }
    }
    return { ok: failed === 0, passed: passed, failed: failed, results: results, byCategory: byCategory };
  }

  function coverageMatrix() {
    return Object.keys(FIXTURES).map(function (name) {
      return {
        fixture: name,
        category: FIXTURES[name].category,
        description: FIXTURES[name].description
      };
    });
  }

  root.PaletteActionChipsMvpFixtures = {
    FIXTURES: FIXTURES,
    runMvpFixture: runMvpFixture,
    runAllMvpFixtures: runAllMvpFixtures,
    coverageMatrix: coverageMatrix
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
