(function (global) {
  "use strict";

  var MAX_ROWS = 30;

  function rowKey(item, idx) {
    if (!item) return "row_" + idx;
    var id = String(item.id || "");
    var kind = String(item.kind || "");
    var label = String(item.label || item.name || "");
    if (id) return kind + ":" + id;
    if (label) return kind + ":label:" + label;
    return "row_" + idx;
  }

  function patchList(host, rows, selected, buildRowHtml, opts) {
    if (!host) return 0;
    opts = opts || {};
    var lim = Math.min(MAX_ROWS, rows ? rows.length : 0);
    var seen = Object.create(null);
    var touched = 0;

    for (var i = 0; i < lim; i++) {
      var item = rows[i];
      var key = rowKey(item, i);
      seen[key] = true;
      var selector = '[data-row-key="' + key.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"]';
      var node = host.querySelector(selector);
      var html = buildRowHtml(item, i, selected === i);
      if (!node) {
        var wrap = document.createElement("div");
        wrap.innerHTML = html;
        node = wrap.firstElementChild;
        if (!node) continue;
        host.appendChild(node);
        touched += 1;
      } else {
        var nextHtml = html;
        if (node.outerHTML !== nextHtml) {
          var tmp = document.createElement("div");
          tmp.innerHTML = nextHtml;
          var fresh = tmp.firstElementChild;
          if (fresh) {
            node.replaceWith(fresh);
            node = fresh;
            touched += 1;
          }
        }
      }
      node.setAttribute("data-idx", String(i));
      node.setAttribute("data-row-key", key);
      node.classList.toggle("active", selected === i);
    }

    var existing = host.querySelectorAll("[data-row-key]");
    for (var j = existing.length - 1; j >= 0; j--) {
      var el = existing[j];
      var rk = el.getAttribute("data-row-key");
      if (!rk || !seen[rk]) {
        el.remove();
        touched += 1;
      }
    }

    if (opts.hydrateIcons && typeof opts.hydrateFn === "function") {
      opts.hydrateFn(host);
    }
    return touched;
  }

  global.PaletteResultList = {
    MAX_ROWS: MAX_ROWS,
    rowKey: rowKey,
    patchList: patchList
  };
})(typeof window !== "undefined" ? window : globalThis);
