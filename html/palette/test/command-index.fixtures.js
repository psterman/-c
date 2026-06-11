(function (global) {
  "use strict";

  function runCommandIndexFixtures() {
    if (typeof PaletteCommandIndex === "undefined") {
      throw new Error("PaletteCommandIndex missing");
    }
    PaletteCommandIndex.load({
      version: 1,
      items: [
        { id: "open_settings", label: "打开设置", desc: "配置", keywords: ["settings", "config"], kind: "command" },
        { id: "reload", label: "重载脚本", desc: "Reload", keywords: ["reload"], kind: "command" }
      ]
    });
    var hits = PaletteCommandIndex.search("设置", 10);
    if (!hits.length || hits[0].id !== "open_settings") {
      throw new Error("command-index: prefix search failed");
    }
    var gen = typeof PaletteQueryController !== "undefined" ? PaletteQueryController : null;
    if (gen) {
      var g1 = gen.nextGeneration();
      var g2 = gen.nextGeneration();
      if (!gen.isCurrent(g2) || gen.isCurrent(g1) || !gen.dropIfStale(g1)) {
        throw new Error("query-controller: generation stale check failed");
      }
    }
    return { ok: true, hits: hits.length };
  }

  global.PaletteCommandIndexFixtures = { run: runCommandIndexFixtures };
})(typeof globalThis !== "undefined" ? globalThis : this);
