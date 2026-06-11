(function (global) {
  "use strict";

  var MODES = {
    compact: { width: 720, height: 72 },
    list: { width: 720, height: 460 },
    detail: { width: 960, height: 620 }
  };

  var lastMode = "";

  function resolveMode(ctx) {
    ctx = ctx || {};
    if (ctx.forceDetail) return "detail";
    var hasResults = !!ctx.hasResults;
    var hasInput = !!ctx.hasInput;
    var expanded = !!ctx.expanded;
    if (expanded) return "list";
    if (!hasInput && !hasResults) return "compact";
    return "list";
  }

  function requestLayoutMode(mode, postFn) {
    var m = String(mode || "");
    if (!MODES[m]) return false;
    if (m === lastMode) return false;
    lastMode = m;
    if (typeof global.PalettePerfMarks !== "undefined") {
      global.PalettePerfMarks.mark("layout_mode_requested", { layoutMode: m });
    }
    if (typeof postFn === "function") {
      postFn({
        type: "palette_layout_mode",
        mode: m,
        width: MODES[m].width,
        height: MODES[m].height
      });
    }
    return true;
  }

  function resetMode() {
    lastMode = "";
  }

  global.PaletteLayout = {
    MODES: MODES,
    resolveMode: resolveMode,
    requestLayoutMode: requestLayoutMode,
    resetMode: resetMode,
    getLastMode: function () {
      return lastMode;
    }
  };
})(typeof window !== "undefined" ? window : globalThis);
