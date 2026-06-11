(function (global) {
  "use strict";

  var generation = 0;

  function nextGeneration() {
    generation += 1;
    return generation;
  }

  function currentGeneration() {
    return generation;
  }

  function isCurrent(gen) {
    return Number(gen) === generation;
  }

  function dropIfStale(gen) {
    return !isCurrent(gen);
  }

  global.PaletteQueryController = {
    nextGeneration: nextGeneration,
    currentGeneration: currentGeneration,
    isCurrent: isCurrent,
    dropIfStale: dropIfStale
  };
})(typeof window !== "undefined" ? window : globalThis);
