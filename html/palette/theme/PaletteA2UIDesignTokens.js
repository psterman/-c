/**
 * PaletteA2UIDesignTokens — CP 根节点 → NMER / 官方 A2UI 共用 CSS 变量桥。
 * architecture-v2 §9：--palette-a2ui-primary、--palette-a2ui-surface-bg 等由 CP 注入。
 */
(function (root) {
  var TOKEN_KEYS = [
    "--palette-a2ui-primary",
    "--palette-a2ui-primary-muted",
    "--palette-a2ui-surface-bg",
    "--palette-a2ui-surface-border",
    "--palette-a2ui-on-surface",
    "--palette-a2ui-head",
    "--palette-a2ui-slot-bg",
    "--palette-a2ui-slot-border",
    "--palette-a2ui-fallback-bg",
    "--palette-a2ui-fallback-border"
  ];

  var HOST_ALIASES = {
    "--a2ui-primary-color": "--palette-a2ui-primary"
  };

  var PRESETS = {
    dark: {
      "--palette-a2ui-primary": "#ff8d2a",
      "--palette-a2ui-primary-muted": "#fdba74",
      "--palette-a2ui-surface-bg": "rgba(255, 141, 42, 0.06)",
      "--palette-a2ui-surface-border": "rgba(255, 141, 42, 0.3)",
      "--palette-a2ui-on-surface": "#fff9f2",
      "--palette-a2ui-head": "#fdba74",
      "--palette-a2ui-slot-bg": "rgba(255, 141, 42, 0.06)",
      "--palette-a2ui-slot-border": "rgba(255, 141, 42, 0.18)",
      "--palette-a2ui-fallback-bg": "rgba(251, 191, 36, 0.06)",
      "--palette-a2ui-fallback-border": "rgba(251, 191, 36, 0.35)"
    },
    light: {
      "--palette-a2ui-primary": "#c25a00",
      "--palette-a2ui-primary-muted": "#9a4b00",
      "--palette-a2ui-surface-bg": "rgba(255, 141, 42, 0.08)",
      "--palette-a2ui-surface-border": "rgba(194, 90, 0, 0.28)",
      "--palette-a2ui-on-surface": "#1a1a1a",
      "--palette-a2ui-head": "#9a4b00",
      "--palette-a2ui-slot-bg": "rgba(255, 141, 42, 0.05)",
      "--palette-a2ui-slot-border": "rgba(194, 90, 0, 0.15)",
      "--palette-a2ui-fallback-bg": "rgba(251, 191, 36, 0.1)",
      "--palette-a2ui-fallback-border": "rgba(180, 130, 0, 0.35)"
    }
  };

  function normalizeTheme(mode) {
    return String(mode || "").toLowerCase() === "light" ? "light" : "dark";
  }

  function getTokens(themeMode) {
    var key = normalizeTheme(themeMode);
    var preset = PRESETS[key] || PRESETS.dark;
    var out = {};
    TOKEN_KEYS.forEach(function (name) {
      out[name] = preset[name];
    });
    return out;
  }

  function applyTokens(el, themeMode, options) {
    if (!el || !el.style || typeof el.style.setProperty !== "function") return false;
    var tokens = getTokens(themeMode);
    var opts = options || {};
    TOKEN_KEYS.forEach(function (name) {
      if (tokens[name]) el.style.setProperty(name, tokens[name]);
    });
    if (opts.syncHostAliases) {
      Object.keys(HOST_ALIASES).forEach(function (alias) {
        var source = HOST_ALIASES[alias];
        if (tokens[source]) el.style.setProperty(alias, tokens[source]);
      });
    }
    return true;
  }

  function applyToRoot(themeMode) {
    var doc = root.document;
    if (!doc || !doc.documentElement) return false;
    return applyTokens(doc.documentElement, themeMode);
  }

  function applyToHost(hostEl, themeMode) {
    return applyTokens(hostEl, themeMode, { syncHostAliases: true });
  }

  function syncHosts(themeMode, scopeEl) {
    var doc = root.document;
    if (!doc || !doc.querySelectorAll) return 0;
    var scope = scopeEl && scopeEl.querySelectorAll ? scopeEl : doc;
    var nodes = scope.querySelectorAll("nmer-official-a2ui-surface");
    var count = 0;
    for (var i = 0; i < nodes.length; i++) {
      if (applyToHost(nodes[i], themeMode)) count++;
    }
    return count;
  }

  function syncAll(themeMode) {
    applyToRoot(themeMode);
    return syncHosts(themeMode);
  }

  root.PaletteA2UIDesignTokens = {
    TOKEN_KEYS: TOKEN_KEYS.slice(),
    HOST_ALIASES: Object.assign({}, HOST_ALIASES),
    PRESETS: PRESETS,
    normalizeTheme: normalizeTheme,
    getTokens: getTokens,
    applyTokens: applyTokens,
    applyToRoot: applyToRoot,
    applyToHost: applyToHost,
    syncHosts: syncHosts,
    syncAll: syncAll
  };
})(typeof window !== "undefined" ? window : globalThis);
