(function (global) {
  "use strict";
  var api = null;
  function install(ctx) {
    api = ctx || null;
  }
  function bindUI() {
    if (!api) return;
    var input = api.getInputEl();
    var debugBtn = document.getElementById("debug-btn");
    var results = document.getElementById("results");
    if (!input) return;
    api.bindResultsScrollHide(results);
    api.bindInputEvents(input);
    var intentTag = document.getElementById("intent-tag");
    if (intentTag) {
      intentTag.addEventListener("click", function (e) {
        e.preventDefault();
        api.cycleIntent();
      });
    }
    if (debugBtn) {
      debugBtn.addEventListener("click", function (e) {
        e.preventDefault();
        e.stopPropagation();
        var tab = api.state.intent === "action" ? "agent" : "search";
        api.post({ type: "palette_search_debug", tab: tab });
      });
    }
    input.focus();
  }
  global.PaletteShell = {
    install: install,
    bindUI: bindUI
  };
})(typeof window !== "undefined" ? window : globalThis);
