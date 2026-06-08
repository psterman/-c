/**
 * PaletteActionBinder / ActionController 职责边界 fixtures
 */
(function (root) {
  var FIXTURES = {
    boundary_legacy_chip_click: {
      description: "legacy chip click 经 Binder 桥接仍可用"
    },
    boundary_binder_delegates_controller: {
      description: "Binder 不直接执行 intent，仅委托 ActionController"
    },
    boundary_lit_component_source: {
      description: "Lit a2ui-action trace actionSource=lit_component"
    },
    boundary_palette_action_lit_source: {
      description: "palette-action(lit) 直达 ActionController 且 source=lit_component"
    }
  };

  function parseLog(det) {
    try {
      return JSON.parse(det);
    } catch (_) {
      return null;
    }
  }

  function withLegacyInput(cardId, fn) {
    var mockInput = {
      value: "",
      focusCalled: false,
      dataset: {},
      placeholder: "",
      classList: { add: function () {}, remove: function () {} },
      focus: function () {
        this.focusCalled = true;
      },
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

  function runBoundaryFixture(name) {
    var fx = FIXTURES[name];
    if (!fx) return { ok: false, error: "unknown_boundary_fixture:" + name, fixture: name };

    if (name === "boundary_legacy_chip_click") {
      if (!root.PaletteActionBinder || !PaletteActionBinder.handleAction) {
        return { ok: false, error: "binder_missing", fixture: name };
      }
      var logs = [];
      var legacy = withLegacyInput("card-boundary-legacy", function () {
        return PaletteActionBinder.handleAction(
          "card-boundary-legacy",
          { id: "card-boundary-legacy", uiState: "Done" },
          {
            cardId: "card-boundary-legacy",
            chipId: "leg1",
            chip: { id: "leg1", label: "Legacy", kind: "safe", prefill: "legacy text" },
            action: { type: "prefill", value: "legacy text" },
            renderer: "legacy",
            component: "follow-up-chips",
            slot: "actions"
          },
          { debugLog: function (ev, det) { logs.push({ ev: ev, det: det }); } }
        );
      });
      var bridgeLog = logs.find(function (l) { return l.ev === "legacy_action_bridge"; });
      var received = logs.find(function (l) { return l.ev === "a2ui_action_received"; });
      return {
        fixture: name,
        ok:
          legacy.out &&
          legacy.out.ok &&
          legacy.mockInput.value === "legacy text" &&
          !!bridgeLog &&
          !!received &&
          parseLog(received.det).actionSource === "legacy_bridge" &&
          legacy.out.actionSource === "legacy_bridge"
      };
    }

    if (name === "boundary_binder_delegates_controller") {
      if (!root.PaletteActionBinder) return { ok: false, error: "binder_missing", fixture: name };
      var hasIntentHandlers =
        typeof PaletteActionBinder.handlePrefill === "function" ||
        typeof PaletteActionBinder.handleSubmit === "function" ||
        typeof PaletteActionBinder.handleUndo === "function";
      var hasBridge = typeof PaletteActionBinder.bridgeLegacyActionToController === "function";
      var ctrlCalled = false;
      var orig =
        root.PaletteActionController && PaletteActionController.handleA2uiAction
          ? PaletteActionController.handleA2uiAction
          : null;
      if (!orig) return { ok: false, error: "controller_missing", fixture: name };
      PaletteActionController.handleA2uiAction = function (action, ctx) {
        ctrlCalled = true;
        return { ok: true, actionSource: ctx.actionSource, intent: action.intent };
      };
      PaletteActionBinder.handleAction(
        "card-boundary-delegate",
        { id: "card-boundary-delegate" },
        {
          cardId: "card-boundary-delegate",
          chipId: "d1",
          chip: { id: "d1", label: "D", kind: "safe" },
          action: { type: "prefill", value: "d" },
          renderer: "legacy"
        },
        {}
      );
      PaletteActionController.handleA2uiAction = orig;
      return {
        fixture: name,
        ok: !hasIntentHandlers && hasBridge && ctrlCalled
      };
    }

    if (name === "boundary_lit_component_source") {
      if (!root.PaletteA2UIEventBridge || !PaletteA2UIEventBridge.install) {
        return { ok: false, error: "a2ui_bridge_missing", fixture: name };
      }
      if (PaletteA2UIEventBridge._resetForTest) PaletteA2UIEventBridge._resetForTest();
      var litLogs = [];
      var listeners = [];
      var litInput = {
        value: "",
        dataset: {},
        placeholder: "",
        classList: { add: function () {}, remove: function () {} },
        focus: function () {},
        addEventListener: function () {}
      };
      root.document = {
        getElementById: function (id) {
          return id === "card-card-boundary-lit"
            ? { querySelector: function (s) { return s === ".card-followup-input" ? litInput : null; } }
            : null;
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
          return { id: "card-boundary-lit", uiState: "Done" };
        },
        debugLog: function (ev, det) {
          litLogs.push({ ev: ev, det: det });
        }
      });
      listeners.forEach(function (l) {
        if (l.type === "a2ui-action") {
          l.fn({
            detail: { id: "lit1", label: "Lit", intent: "prefill", payload: { text: "lit src" } },
            target: { getAttribute: function (k) { return k === "card-id" ? "card-boundary-lit" : ""; } }
          });
        }
      });
      var receivedLit = litLogs.find(function (l) { return l.ev === "a2ui_action_received"; });
      var litEvent = litLogs.find(function (l) { return l.ev === "action_chips_lit_event"; });
      return {
        fixture: name,
        ok:
          !!receivedLit &&
          parseLog(receivedLit.det).actionSource === "lit_component" &&
          !!litEvent &&
          parseLog(litEvent.det).actionSource === "lit_component"
      };
    }

    if (name === "boundary_palette_action_lit_source") {
      if (!root.PaletteUIEventBridge || !PaletteUIEventBridge.install) {
        return { ok: false, error: "ui_bridge_missing", fixture: name };
      }
      var paLogs = [];
      var paListeners = [];
      root.document = {
        addEventListener: function (type, fn) {
          paListeners.push({ type: type, fn: fn });
        },
        removeEventListener: function () {},
        getElementById: function () {
          return null;
        }
      };
      PaletteUIEventBridge.install({
        getCard: function () {
          return { id: "card-boundary-pa", uiState: "Done" };
        },
        debugLog: function (ev, det) {
          paLogs.push({ ev: ev, det: det });
        }
      });
      paListeners.forEach(function (l) {
        if (l.type === "palette-action") {
          l.fn({
            detail: {
              cardId: "card-boundary-pa",
              chipId: "pa1",
              chip: { id: "pa1", label: "PA Lit", kind: "safe", prefill: "pa lit" },
              action: { type: "prefill", value: "pa lit" },
              renderer: "lit",
              component: "follow-up-chips",
              slot: "actions"
            }
          });
        }
      });
      var receivedPa = paLogs.find(function (l) { return l.ev === "a2ui_action_received"; });
      return {
        fixture: name,
        ok: !!receivedPa && parseLog(receivedPa.det).actionSource === "lit_component"
      };
    }

    return { ok: false, error: "unhandled_boundary_fixture", fixture: name };
  }

  function runAllBoundaryFixtures() {
    var names = Object.keys(FIXTURES);
    var results = [];
    var passed = 0;
    var failed = 0;
    for (var i = 0; i < names.length; i++) {
      var out = runBoundaryFixture(names[i]);
      out.fixture = names[i];
      results.push(out);
      if (out.ok) passed++;
      else failed++;
    }
    return { ok: failed === 0, passed: passed, failed: failed, results: results };
  }

  root.PaletteActionBoundaryFixtures = {
    FIXTURES: FIXTURES,
    runBoundaryFixture: runBoundaryFixture,
    runAllBoundaryFixtures: runAllBoundaryFixtures
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
