(function (global) {
  "use strict";

  function createCoalescer(opts) {
    opts = opts || {};
    var intervalMs = opts.intervalMs != null ? Number(opts.intervalMs) : 50;
    var hiddenIntervalMs = opts.hiddenIntervalMs != null ? Number(opts.hiddenIntervalMs) : 100;
    var timers = Object.create(null);
    var pending = Object.create(null);

    function currentInterval() {
      try {
        if (typeof document !== "undefined" && document.hidden) return hiddenIntervalMs;
      } catch (_) {}
      return intervalMs;
    }

    function schedule(cardId, flushOne, flushAll) {
      var id = String(cardId || "");
      if (!id) return;
      pending[id] = true;
      if (timers[id]) return;
      timers[id] = setTimeout(function () {
        timers[id] = 0;
        delete pending[id];
        if (typeof flushOne === "function") flushOne(id);
        if (typeof flushAll === "function") flushAll();
      }, currentInterval());
    }

    function flushNow(cardId, flushOne, flushAll) {
      var id = String(cardId || "");
      if (id) {
        if (timers[id]) {
          clearTimeout(timers[id]);
          timers[id] = 0;
        }
        delete pending[id];
        if (typeof flushOne === "function") flushOne(id);
      } else {
        Object.keys(timers).forEach(function (k) {
          if (timers[k]) clearTimeout(timers[k]);
          delete timers[k];
        });
        timers = Object.create(null);
        pending = Object.create(null);
      }
      if (typeof flushAll === "function") flushAll();
    }

    function destroy() {
      Object.keys(timers).forEach(function (k) {
        if (timers[k]) clearTimeout(timers[k]);
      });
      timers = Object.create(null);
      pending = Object.create(null);
    }

    return {
      schedule: schedule,
      flushNow: flushNow,
      destroy: destroy,
      hasPending: function (cardId) {
        return !!pending[String(cardId || "")];
      }
    };
  }

  global.PaletteAgentChunkCoalescer = {
    create: createCoalescer
  };
})(typeof window !== "undefined" ? window : globalThis);
