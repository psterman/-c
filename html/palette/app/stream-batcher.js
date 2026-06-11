(function (global) {
  "use strict";

  function createBatcher(flushFn, opts) {
    opts = opts || {};
    var intervalMs = opts.intervalMs != null ? Number(opts.intervalMs) : 50;
    var hiddenIntervalMs = opts.hiddenIntervalMs != null ? Number(opts.hiddenIntervalMs) : 100;
    var queue = [];
    var timer = 0;
    var destroyed = false;

    function currentInterval() {
      try {
        if (typeof document !== "undefined" && document.hidden) return hiddenIntervalMs;
      } catch (_) {}
      return intervalMs;
    }

    function flushNow() {
      if (destroyed || !queue.length) return;
      var batch = queue.slice();
      queue = [];
      if (timer) {
        clearTimeout(timer);
        timer = 0;
      }
      try {
        flushFn(batch);
      } catch (_) {}
    }

    function schedule() {
      if (timer || destroyed) return;
      timer = setTimeout(function () {
        timer = 0;
        flushNow();
      }, currentInterval());
    }

    return {
      push: function (item, immediate) {
        if (destroyed) return;
        if (immediate) {
          queue.push(item);
          flushNow();
          return;
        }
        queue.push(item);
        schedule();
      },
      flushNow: flushNow,
      destroy: function () {
        destroyed = true;
        if (timer) clearTimeout(timer);
        timer = 0;
        queue = [];
      }
    };
  }

  global.PaletteStreamBatcher = {
    create: createBatcher
  };
})(typeof window !== "undefined" ? window : globalThis);
