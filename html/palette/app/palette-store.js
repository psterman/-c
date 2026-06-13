(function (global) {
  "use strict";

  var state = {
    input: "",
    intent: "action",
    actions: [],
    turboItems: [],
    aiProviders: [],
    selectedAiProvider: "",
    resultMode: "command",
    selected: 0,
    voiceStatus: "idle",
    voiceHint: "",
    showResults: false,
    turboQuery: "",
    querySeq: 0,
    _userPickedCommand: false,
    actionCmdBrowse: false,
    _actionQueryCache: [],
    paletteFlags: {
      fastInput: false,
      discreteLayout: false,
      streamBatching: false,
      stateStore: false,
      stateStoreShadow: false,
      agentTransport: "auto",
      openclawAnswerSync: true
    },
    agentProvider: "openclaw"
  };

  var actionState = {
    activeCardId: null,
    detailCardId: null,
    cards: {},
    _pendingCardId: null,
    _batchUpsert: 0,
    historyFilter: "all",
    focusMode: false,
    showAllDone: true
  };

  function applyPaletteFlags(d, hooks) {
    hooks = hooks || {};
    if (!d || typeof d !== "object") return;
    state.paletteFlags = {
      fastInput: !!d.fastInput,
      discreteLayout: !!d.discreteLayout,
      streamBatching: !!d.streamBatching,
      stateStore: !!d.stateStore,
      stateStoreShadow: !!d.stateStoreShadow,
      agentTransport: String(d.agentTransport || "auto"),
      openclawAnswerSync: d.openclawAnswerSync !== false
    };
    if (typeof hooks.afterApply === "function") hooks.afterApply(state);
  }

  global.PaletteStore = {
    getState: function () {
      return state;
    },
    getActionState: function () {
      return actionState;
    },
    applyPaletteFlags: applyPaletteFlags
  };
})(typeof window !== "undefined" ? window : globalThis);
