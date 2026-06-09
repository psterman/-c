/**

 * PaletteActionController fixtures

 */

(function (root) {

  var FIXTURES = {

    controller_prefill_input: {

      description: "prefill intent 填入输入框并 focus",

      card: { id: "card-ctrl-prefill", uiState: "Done" },

      action: {

        id: "pf1",

        label: "补充说明",

        intent: "prefill",

        payload: { text: "请补充说明" }

      }

    },

    controller_prefill_hint_placeholder: {

      description: "prefill 设置 hint placeholder",

      card: { id: "card-ctrl-hint", uiState: "Done" },

      action: {

        id: "pf2",

        label: "建议",

        intent: "prefill",

        payload: { text: "建议文本" }

      }

    },

    controller_prefill_user_input_clears_hint: {

      description: "用户 input 后 hint 清除",

      card: { id: "card-ctrl-input-clear", uiState: "Done" },

      action: {

        id: "pf3",

        label: "填入",

        intent: "prefill",

        payload: { text: "填入内容" }

      }

    },

    controller_prefill_timeout_clears_hint: {

      description: "timeout 后 hint 清除",

      card: { id: "card-ctrl-timeout", uiState: "Done" },

      action: {

        id: "pf4",

        label: "超时",

        intent: "prefill",

        payload: { text: "超时内容" }

      }

    },

    controller_prefill_undo_restore: {

      description: "undo 恢复 previousInputValue",

      card: { id: "card-ctrl-undo", uiState: "Done" },

      prefillAction: {

        id: "pf5",

        label: "覆盖",

        intent: "prefill",

        payload: { text: "新建议" }

      },

      undoAction: {

        id: "undo1",

        label: "撤销",

        intent: "undo",

        payload: {}

      },

      initialValue: "原有内容"

    },

    controller_submit_handler: {

      description: "submit intent 调用 submitFollowup handler",

      card: { id: "card-ctrl-submit", uiState: "Done" },

      action: {

        id: "sb1",

        label: "立即发送",

        intent: "submit",

        payload: { text: "发送这条" }

      }

    },

    controller_submit_pending_disables: {

      description: "submit pending 期间 chip disabled",

      card: { id: "card-ctrl-pending", uiState: "Done" },

      action: {

        id: "sb2",

        label: "发送",

        intent: "submit",

        payload: { text: "pending 测试" }

      }

    },

    controller_submit_async_dedupes: {

      description: "异步 submit pending 期间相同 action 只提交一次",

      card: { id: "card-ctrl-async-dedupe", uiState: "Done" },

      action: {

        id: "sb_async",

        label: "异步发送",

        intent: "submit",

        payload: { text: "异步发送内容" }

      }

    },

    controller_unsupported_no_throw: {

      description: "unsupported intent 不抛异常",

      card: { id: "card-ctrl-inspect", uiState: "Done" },

      action: {

        id: "in1",

        label: "查看详情",

        intent: "inspect",

        payload: { text: "detail" }

      }

    },

    controller_legacy_detail_bridge: {

      description: "legacy chip detail 可转换为标准 action 并 prefill",

      card: { id: "card-ctrl-legacy", uiState: "Done" },

      detail: {

        cardId: "card-ctrl-legacy",

        chipId: "legacy1",

        chip: { id: "legacy1", label: "Legacy chip", kind: "safe" },

        action: { type: "prefill", value: "legacy prefill text" },

        dataSource: "merged",

        renderer: "legacy"

      }

    },

    controller_prefill_headless_mock_safe: {

      description: "headless mock 无 dataset/setTimeout/focus 不报错",

      card: { id: "card-ctrl-mock-safe", uiState: "Done" },

      action: {

        id: "pf6",

        label: "安全",

        intent: "prefill",

        payload: { text: "mock safe" }

      }

    },

    controller_disabled_action: {

      description: "disabled action 不执行 prefill / submit",

      card: { id: "card-ctrl-disabled", uiState: "Done" },

      prefillAction: {

        id: "dis_pf",

        label: "禁用预填",

        intent: "prefill",

        payload: { text: "不应填入" },

        disabled: true

      },

      submitAction: {

        id: "dis_sb",

        label: "禁用发送",

        intent: "submit",

        payload: { text: "不应发送" },

        disabled: true

      }

    },

    controller_action_clicked_action_source: {

      description: "action_clicked trace 含 actionSource",

      card: { id: "card-ctrl-as", uiState: "Done" },

      action: {

        id: "as1",

        label: "Trace",

        intent: "prefill",

        payload: { text: "trace text" }

      }

    },

    controller_prefill_is_prefilled_class: {

      description: "prefill 后 is-prefilled 出现，超时后清除",

      card: { id: "card-ctrl-prefilled-cls", uiState: "Done" },

      action: {

        id: "pf_cls",

        label: "样式",

        intent: "prefill",

        payload: { text: "class test" }

      }

    }

  };



  function parseLog(det) {

    try {

      return JSON.parse(det);

    } catch (_) {

      return null;

    }

  }

  function makeTrackableClassList() {

    var classes = {};

    return {

      add: function (c) {

        classes[c] = true;

      },

      remove: function (c) {

        delete classes[c];

      },

      contains: function (c) {

        return !!classes[c];

      },

      _classes: classes

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

      classList: opts.trackClass ? makeTrackableClassList() : { add: function () {}, remove: function () {} },

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



  function withMockDom(cardId, inputOpts, fn) {

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



  function runControllerFixture(name) {

    var fx = FIXTURES[name];

    if (!fx) return { ok: false, error: "unknown_controller_fixture:" + name, fixture: name };

    if (!root.PaletteActionController || !PaletteActionController.handleA2uiAction) {

      return { ok: false, error: "controller_missing", fixture: name };

    }



    var logs = [];

    var contextBase = {

      debugLog: function (ev, det) {

        logs.push({ ev: ev, det: det });

      }

    };

    var hintText =

      PaletteActionController.PREFILL_HINT_TEXT || "已从建议填入，可继续编辑后发送";

    var hintMs = PaletteActionController.PREFILL_HINT_MS || 1900;



    if (name === "controller_prefill_input") {

      var pre = withMockDom(fx.card.id, {}, function (mockInput) {

        return PaletteActionController.handleA2uiAction(fx.action, Object.assign({}, contextBase, {

          cardId: fx.card.id,

          card: fx.card,

          chipId: fx.action.id

        }));

      });

      return {

        fixture: name,

        ok:

          pre.out &&

          pre.out.ok &&

          pre.mockInput.value === "请补充说明" &&

          pre.mockInput.focusCalled &&

          pre.mockInput.dataset &&

          pre.mockInput.dataset.prefillHint === "1" &&

          logs.some(function (l) { return l.ev === "a2ui_action_prefill"; })

      };

    }



    if (name === "controller_prefill_hint_placeholder") {

      var hint = withMockDom(fx.card.id, {}, function () {

        return PaletteActionController.handleA2uiAction(fx.action, Object.assign({}, contextBase, {

          cardId: fx.card.id,

          card: fx.card,

          chipId: fx.action.id

        }));

      });

      return {

        fixture: name,

        ok:

          hint.out &&

          hint.out.ok &&

          hint.mockInput.placeholder === hintText &&

          hint.mockInput.dataset &&

          hint.mockInput.dataset.prefillHint === "1"

      };

    }



    if (name === "controller_prefill_user_input_clears_hint") {

      var userClear = withMockDom(fx.card.id, {}, function (mockInput) {

        PaletteActionController.handleA2uiAction(fx.action, Object.assign({}, contextBase, {

          cardId: fx.card.id,

          card: fx.card,

          chipId: fx.action.id

        }));

        mockInput._dispatchInput();

        return mockInput;

      });

      return {

        fixture: name,

        ok:

          userClear.mockInput.dataset &&

          userClear.mockInput.dataset.prefillHint !== "1" &&

          userClear.mockInput.placeholder === "追加新指令…"

      };

    }



    if (name === "controller_prefill_timeout_clears_hint") {

      var timers = [];

      var savedSetTimeout = root.setTimeout;

      var savedClearTimeout = root.clearTimeout;

      root.setTimeout = function (fn, ms) {

        timers.push({ fn: fn, ms: ms });

        return timers.length;

      };

      root.clearTimeout = function () {};

      var timeoutRun = withMockDom(fx.card.id, {}, function () {

        PaletteActionController.handleA2uiAction(fx.action, Object.assign({}, contextBase, {

          cardId: fx.card.id,

          card: fx.card,

          chipId: fx.action.id

        }));

        var hintTimer = timers.filter(function (t) { return t.ms === hintMs; })[0];

        if (hintTimer && hintTimer.fn) hintTimer.fn();

        return true;

      });

      if (savedSetTimeout !== undefined) root.setTimeout = savedSetTimeout;

      else delete root.setTimeout;

      if (savedClearTimeout !== undefined) root.clearTimeout = savedClearTimeout;

      else delete root.clearTimeout;

      return {

        fixture: name,

        ok:

          timeoutRun.mockInput.dataset &&

          timeoutRun.mockInput.dataset.prefillHint !== "1" &&

          timeoutRun.mockInput.placeholder === "追加新指令…"

      };

    }



    if (name === "controller_prefill_undo_restore") {

      var cardUndo = Object.assign({}, fx.card);

      var undoRun = withMockDom(

        fx.card.id,

        { value: fx.initialValue },

        function () {

          PaletteActionController.handleA2uiAction(fx.prefillAction, Object.assign({}, contextBase, {

            cardId: fx.card.id,

            card: cardUndo,

            chipId: fx.prefillAction.id

          }));

          return PaletteActionController.handleA2uiAction(fx.undoAction, Object.assign({}, contextBase, {

            cardId: fx.card.id,

            card: cardUndo,

            chipId: fx.undoAction.id

          }));

        }

      );

      return {

        fixture: name,

        ok:

          undoRun.out &&

          undoRun.out.ok &&

          undoRun.mockInput.value === fx.initialValue &&

          cardUndo._prefillPreviousInputValue === fx.initialValue &&

          logs.some(function (l) { return l.ev === "a2ui_action_undo"; })

      };

    }



    if (name === "controller_submit_handler") {

      var submitCalls = [];

      var sub = withMockDom(fx.card.id, {}, function () {

        return PaletteActionController.handleA2uiAction(fx.action, Object.assign({}, contextBase, {

          cardId: fx.card.id,

          card: fx.card,

          chipId: fx.action.id,

          submitFollowup: function (text) {

            submitCalls.push(String(text || ""));

            return true;

          }

        }));

      });

      return {

        fixture: name,

        ok:

          sub.out &&

          sub.out.ok &&

          submitCalls.length === 1 &&

          submitCalls[0] === "发送这条" &&

          logs.some(function (l) { return l.ev === "a2ui_action_submit"; })

      };

    }



    if (name === "controller_submit_pending_disables") {

      var cardPending = Object.assign({}, fx.card);

      var pendingDuringSubmit = false;

      var pendingClearedAfter = false;

      var pendingChipDisabled = false;

      var submitAction = {

        id: fx.action.id,

        label: fx.action.label,

        intent: "submit",

        payload: fx.action.payload,

        disabled: false

      };

      withMockDom(fx.card.id, {}, function () {

        PaletteActionController.handleA2uiAction(fx.action, Object.assign({}, contextBase, {

          cardId: fx.card.id,

          card: cardPending,

          chipId: fx.action.id,

          submitFollowup: function () {

            pendingDuringSubmit = cardPending.pendingActionId === fx.action.id;

            pendingChipDisabled =

              !!cardPending.pendingActionId &&

              submitAction.id === cardPending.pendingActionId;

            return true;

          }

        }));

        pendingClearedAfter = !cardPending.pendingActionId;

        return true;

      });

      return {

        fixture: name,

        ok: pendingDuringSubmit && pendingChipDisabled && pendingClearedAfter

      };

    }

    if (name === "controller_submit_async_dedupes") {

      var asyncCard = Object.assign({}, fx.card);

      var submitCount = 0;

      var settle;

      var pendingThenable = {

        then: function (resolve) {

          settle = resolve;

        }

      };

      var asyncRun = withMockDom(fx.card.id, {}, function () {

        var context = Object.assign({}, contextBase, {

          cardId: fx.card.id,

          blockId: "blk_async",

          card: asyncCard,

          chipId: fx.action.id,

          submitFollowup: function () {

            submitCount++;

            return pendingThenable;

          }

        });

        var first = PaletteActionController.handleA2uiAction(fx.action, context);

        var duplicate = PaletteActionController.handleA2uiAction(fx.action, context);

        return {

          firstIsPromise: !!first && typeof first.then === "function",

          duplicate: duplicate,

          pendingActionId: asyncCard.pendingActionId,

          submitCount: submitCount

        };

      });

      if (settle) settle(true);

      return {

        fixture: name,

        ok:

          asyncRun.out.firstIsPromise &&

          asyncRun.out.submitCount === 1 &&

          asyncRun.out.pendingActionId === fx.action.id &&

          asyncRun.out.duplicate &&

          asyncRun.out.duplicate.deduped === true &&

          asyncRun.out.duplicate.reason === "action_pending" &&

          logs.some(function (l) { return l.ev === "a2ui_action_deduped"; })

      };

    }



    if (name === "controller_unsupported_no_throw") {

      var threw = false;

      var unsupported;

      try {

        unsupported = PaletteActionController.handleA2uiAction(fx.action, Object.assign({}, contextBase, {

          cardId: fx.card.id,

          card: fx.card,

          chipId: fx.action.id

        }));

      } catch (_) {

        threw = true;

      }

      return {

        fixture: name,

        ok:

          !threw &&

          unsupported &&

          unsupported.ok === true &&

          unsupported.handled === false &&

          logs.some(function (l) { return l.ev === "a2ui_action_unsupported"; })

      };

    }



    if (name === "controller_legacy_detail_bridge") {

      if (!PaletteActionController.legacyDetailToA2uiAction) {

        return { ok: false, error: "legacy_bridge_missing", fixture: name };

      }

      if (!root.PaletteActionBinder || !PaletteActionBinder.handleAction) {

        return { ok: false, error: "binder_missing", fixture: name };

      }

      var converted = PaletteActionController.legacyDetailToA2uiAction(fx.detail, fx.card, {});

      var legacy = withMockDom(fx.card.id, {}, function (mockInput) {

        return PaletteActionBinder.handleAction(fx.card.id, fx.card, fx.detail, {

          debugLog: contextBase.debugLog

        });

      });

      return {

        fixture: name,

        ok:

          converted &&

          converted.intent === "prefill" &&

          converted.payload &&

          converted.payload.text === "legacy prefill text" &&

          legacy.out &&

          legacy.out.ok &&

          legacy.mockInput.value === "legacy prefill text" &&

          logs.some(function (l) { return l.ev === "a2ui_action_received"; })

      };

    }



    if (name === "controller_prefill_headless_mock_safe") {

      var threwSafe = false;

      var safeOut;

      try {

        safeOut = withMockDom(

          fx.card.id,

          { noDataset: true, noFocus: true },

          function () {

            return PaletteActionController.handleA2uiAction(fx.action, Object.assign({}, contextBase, {

              cardId: fx.card.id,

              card: fx.card,

              chipId: fx.action.id

            }));

          }

        );

      } catch (_) {

        threwSafe = true;

      }

      var savedSt = root.setTimeout;

      delete root.setTimeout;

      var threwNoTimer = false;

      try {

        withMockDom(fx.card.id, { noDataset: true, noFocus: true }, function () {

          return PaletteActionController.handleA2uiAction(fx.action, Object.assign({}, contextBase, {

            cardId: fx.card.id,

            card: fx.card,

            chipId: fx.action.id

          }));

        });

      } catch (_) {

        threwNoTimer = true;

      }

      if (savedSt !== undefined) root.setTimeout = savedSt;

      return {

        fixture: name,

        ok:

          !threwSafe &&

          !threwNoTimer &&

          safeOut &&

          safeOut.out &&

          safeOut.out.ok &&

          safeOut.mockInput.value === "mock safe"

      };

    }



    if (name === "controller_disabled_action") {

      var submitCalls = [];

      var disPre = withMockDom(fx.card.id, { value: "保持原值" }, function (mockInput) {

        var preOut = PaletteActionController.handleA2uiAction(fx.prefillAction, Object.assign({}, contextBase, {

          cardId: fx.card.id,

          card: fx.card,

          chipId: fx.prefillAction.id

        }));

        var subOut = PaletteActionController.handleA2uiAction(fx.submitAction, Object.assign({}, contextBase, {

          cardId: fx.card.id,

          card: fx.card,

          chipId: fx.submitAction.id,

          submitFollowup: function (text) {

            submitCalls.push(String(text || ""));

            return true;

          }

        }));

        return { preOut: preOut, subOut: subOut, inputValue: mockInput.value };

      });

      return {

        fixture: name,

        ok:

          disPre.out &&

          disPre.out.preOut &&

          disPre.out.subOut &&

          disPre.out.preOut.ok === false &&

          disPre.out.preOut.reason === "disabled" &&

          disPre.out.subOut.ok === false &&

          disPre.out.subOut.reason === "disabled" &&

          disPre.out.inputValue === "保持原值" &&

          submitCalls.length === 0 &&

          logs.some(function (l) {

            if (l.ev !== "a2ui_action_unsupported") return false;

            var obj = parseLog(l.det);

            return obj && obj.reason === "disabled";

          })

      };

    }



    if (name === "controller_action_clicked_action_source") {

      var asRun = withMockDom(fx.card.id, {}, function () {

        return PaletteActionController.handleA2uiAction(fx.action, Object.assign({}, contextBase, {

          cardId: fx.card.id,

          card: fx.card,

          chipId: fx.action.id,

          renderer: "lit",

          component: "ActionChips",

          actionSource: "lit_component"

        }));

      });

      var clicked = logs.filter(function (l) { return l.ev === "action_clicked"; })[0];

      var clickedObj = clicked ? parseLog(clicked.det) : null;

      return {

        fixture: name,

        ok:

          asRun.out &&

          asRun.out.ok &&

          clickedObj &&

          clickedObj.actionSource === "lit_component"

      };

    }



    if (name === "controller_prefill_is_prefilled_class") {

      var clsTimers = [];

      var savedClsSetTimeout = root.setTimeout;

      var savedClsClearTimeout = root.clearTimeout;

      root.setTimeout = function (fn, ms) {

        clsTimers.push({ fn: fn, ms: ms });

        return clsTimers.length;

      };

      root.clearTimeout = function () {};

      var clsRun = withMockDom(

        fx.card.id,

        { trackClass: true },

        function (mockInput) {

          PaletteActionController.handleA2uiAction(fx.action, Object.assign({}, contextBase, {

            cardId: fx.card.id,

            card: fx.card,

            chipId: fx.action.id

          }));

          var hadClass = mockInput.classList.contains("is-prefilled");

          var classTimer = clsTimers.filter(function (t) { return t.ms === 1800; })[0];

          if (classTimer && classTimer.fn) classTimer.fn();

          var cleared = !mockInput.classList.contains("is-prefilled");

          return { hadClass: hadClass, cleared: cleared };

        }

      );

      if (savedClsSetTimeout !== undefined) root.setTimeout = savedClsSetTimeout;

      else delete root.setTimeout;

      if (savedClsClearTimeout !== undefined) root.clearTimeout = savedClsClearTimeout;

      else delete root.clearTimeout;

      return {

        fixture: name,

        ok: clsRun.out && clsRun.out.hadClass === true && clsRun.out.cleared === true

      };

    }



    return { ok: false, error: "unhandled_fixture", fixture: name };

  }



  function runAllControllerFixtures() {

    var names = Object.keys(FIXTURES);

    var results = [];

    var passed = 0;

    var failed = 0;

    for (var i = 0; i < names.length; i++) {

      var out = runControllerFixture(names[i]);

      out.fixture = names[i];

      results.push(out);

      if (out.ok) passed++;

      else failed++;

    }

    return { ok: failed === 0, passed: passed, failed: failed, results: results };

  }



  root.PaletteActionControllerFixtures = {

    FIXTURES: FIXTURES,

    runControllerFixture: runControllerFixture,

    runAllControllerFixtures: runAllControllerFixtures

  };

})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);

