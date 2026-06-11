(function (global) {
  "use strict";

  var snapshotVersion = 0;
  var items = [];

  function normalizeItem(raw) {
    if (!raw || typeof raw !== "object") return null;
    var id = String(raw.id || raw.cmdId || "");
    var label = String(raw.label || raw.name || id);
    if (!label) return null;
    var kws = [];
    if (Array.isArray(raw.keywords)) {
      for (var i = 0; i < raw.keywords.length; i++) {
        kws.push(String(raw.keywords[i] || ""));
      }
    }
    return {
      id: id,
      label: label,
      desc: String(raw.desc || ""),
      binding: String(raw.binding || ""),
      keywords: kws,
      kind: String(raw.kind || "command")
    };
  }

  function scoreCommand(name, keywords, q) {
    if (!q) return 1;
    var label = String(name || "").toLowerCase();
    var query = String(q || "");
    if (label.slice(0, query.length) === query) return 120;
    if (label.indexOf(query) >= 0) return 90;
    var score = 0;
    for (var i = 0; i < keywords.length; i++) {
      var kl = String(keywords[i] || "").toLowerCase();
      if (kl.slice(0, query.length) === query) {
        if (score < 80) score = 80;
        continue;
      }
      if (kl.indexOf(query) >= 0 && score < 60) score = 60;
    }
    if (!score) {
      var parts = query.split(/\s+/);
      for (var j = 0; j < parts.length; j++) {
        var p = String(parts[j] || "").trim();
        if (p && label.indexOf(p) >= 0) score += 20;
      }
    }
    return score;
  }

  function load(msg) {
    var list = msg && Array.isArray(msg.items) ? msg.items : [];
    items = [];
    for (var i = 0; i < list.length; i++) {
      var row = normalizeItem(list[i]);
      if (row) items.push(row);
    }
    snapshotVersion = msg && msg.version != null ? Number(msg.version) : items.length;
    return items.length;
  }

  function search(query, limit) {
    var q = String(query || "").trim().toLowerCase();
    var lim = limit != null ? Math.max(1, Number(limit) || 30) : 30;
    if (!q) return [];
    var scored = [];
    for (var i = 0; i < items.length; i++) {
      var it = items[i];
      var s = scoreCommand(it.label, it.keywords, q);
      if (s <= 0) continue;
      scored.push({
        score: s,
        id: it.id,
        label: it.label,
        desc: it.desc,
        binding: it.binding,
        matched: true,
        kind: it.kind || "command"
      });
    }
    scored.sort(function (a, b) {
      if (b.score !== a.score) return b.score - a.score;
      return String(a.label).localeCompare(String(b.label));
    });
    return scored.slice(0, lim);
  }

  global.PaletteCommandIndex = {
    load: load,
    search: search,
    getVersion: function () {
      return snapshotVersion;
    },
    getSize: function () {
      return items.length;
    }
  };
})(typeof window !== "undefined" ? window : globalThis);
