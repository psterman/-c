/* SearchCenter chunk lazy-loader — always loaded with SearchCenter.html */
(function (global) {
  "use strict";

  const SC_CHUNK_ASSETS = {
    web: {
      css: "https://app.local/assets/css/sc-web-embed.css",
      js: "https://app.local/assets/js/sc-web-embed.js",
      cssId: "sc-chunk-css-web"
    },
    cli: {
      css: "https://app.local/assets/css/sc-cli.css",
      js: "https://app.local/assets/js/sc-cli.js",
      cssId: "sc-chunk-css-cli"
    }
  };

  const _loaded = Object.create(null);
  const _pending = Object.create(null);

  function loadStylesheet(href, id) {
    if (!href) return Promise.resolve();
    if (document.getElementById(id)) return Promise.resolve();
    return new Promise((resolve, reject) => {
      const link = document.createElement("link");
      link.id = id;
      link.rel = "stylesheet";
      link.href = href;
      link.onload = () => resolve();
      link.onerror = () => reject(new Error("css load failed: " + href));
      document.head.appendChild(link);
    });
  }

  function loadScript(src) {
    return new Promise((resolve, reject) => {
      const s = document.createElement("script");
      s.src = src;
      s.async = false;
      s.onload = () => resolve();
      s.onerror = () => reject(new Error("script load failed: " + src));
      document.head.appendChild(s);
    });
  }

  async function ensureScChunk(name) {
    const key = String(name || "");
    if (_loaded[key]) return true;
    const spec = SC_CHUNK_ASSETS[key];
    if (!spec) return false;
    if (!_pending[key]) {
      _pending[key] = (async () => {
        await loadStylesheet(spec.css, spec.cssId);
        await loadScript(spec.js);
        _loaded[key] = true;
      })();
    }
    await _pending[key];
    return true;
  }

  function isScChunkLoaded(name) {
    return !!_loaded[String(name || "")];
  }

  global.ScChunkLoader = {
    SC_CHUNK_ASSETS,
    ensureScChunk,
    isScChunkLoaded
  };
})(typeof window !== "undefined" ? window : globalThis);
