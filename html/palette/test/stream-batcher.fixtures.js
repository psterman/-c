(function (global) {
  "use strict";

  function runStreamBatcherFixtures() {
    if (typeof PaletteStreamBatcher === "undefined") {
      throw new Error("PaletteStreamBatcher missing");
    }
    var flushed = [];
    var batcher = PaletteStreamBatcher.create(function (batch) {
      flushed.push(batch.join(""));
    }, { intervalMs: 20, hiddenIntervalMs: 20 });
    batcher.push("a");
    batcher.push("b");
    batcher.push("c", true);
    if (flushed.length !== 1 || flushed[0] !== "abc") {
      throw new Error("stream-batcher: immediate flush failed");
    }
    batcher.destroy();

    if (typeof PaletteAgentChunkCoalescer === "undefined") {
      throw new Error("PaletteAgentChunkCoalescer missing");
    }
    var hits = [];
    var co = PaletteAgentChunkCoalescer.create({ intervalMs: 10, hiddenIntervalMs: 10 });
    co.flushNow(
      "card-1",
      function (id) {
        hits.push(id);
      },
      function () {
        hits.push("all");
      }
    );
    if (hits.indexOf("card-1") < 0 || hits.indexOf("all") < 0) {
      throw new Error("agent-chunk-coalescer: flushNow failed");
    }
    co.destroy();
    return { ok: true };
  }

  global.PaletteStreamBatcherFixtures = { run: runStreamBatcherFixtures };
})(typeof globalThis !== "undefined" ? globalThis : this);
