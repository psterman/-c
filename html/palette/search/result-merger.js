(function (global) {
  "use strict";

  function currentRows(state) {
    if (!state) return [];
    if (state.resultMode === "turbo") return state.turboItems || [];
    return state.actions || [];
  }

  global.PaletteResultMerger = {
    currentRows: currentRows
  };
})(typeof window !== "undefined" ? window : globalThis);
