(function (global) {
  "use strict";

  function buildHtml(item, idx, active, ctx) {
    ctx = ctx || {};
    var esc = typeof ctx.esc === "function" ? ctx.esc : function (t) { return String(t || ""); };
    var kindIconFn = typeof ctx.kindIcon === "function" ? ctx.kindIcon : function () { return ""; };
    var renderProviderIconHtml =
      typeof ctx.renderProviderIconHtml === "function" ? ctx.renderProviderIconHtml : function () { return ""; };
    var isAiConfigured = typeof ctx.isAiConfigured === "function" ? ctx.isAiConfigured : function () { return false; };
    var selectedAiProvider = String(ctx.selectedAiProvider || "");

    var activeCls = active ? " active" : "";
    var matched = item.matched ? " matched" : "";
    var kind = item.kind ? " kind-" + esc(item.kind) : "";
    var binding = item.binding ? '<span class="result-binding">' + esc(item.binding) + "</span>" : "";
    if (!binding && item.kind === "ai_provider") {
      if (String(item.id || "") === selectedAiProvider) binding = '<span class="result-binding">已选</span>';
      else if (isAiConfigured(item)) binding = '<span class="result-binding">已配置</span>';
    }
    var icon = item.kind === "ai_provider" ? renderProviderIconHtml(item) : kindIconFn(item.kind || "command");
    var rowKey =
      typeof global.PaletteResultList !== "undefined"
        ? global.PaletteResultList.rowKey(item, idx)
        : String(item.id || item.label || idx);
    return (
      '<button class="result-item' +
      activeCls +
      matched +
      kind +
      '" type="button" data-idx="' +
      idx +
      '" data-row-key="' +
      esc(rowKey) +
      '">' +
      '<span class="result-icon" aria-hidden="true">' +
      icon +
      "</span>" +
      '<span class="result-body">' +
      '<div class="result-row"><span class="result-title">' +
      esc(item.label || item.name || "") +
      "</span>" +
      binding +
      "</div>" +
      '<span class="result-desc">' +
      esc(item.desc || "") +
      "</span></span></button>"
    );
  }

  function hydrateIcons(box, ctx) {
    if (!box) return;
    ctx = ctx || {};
    var findAiProviderItem = typeof ctx.findAiProviderItem === "function" ? ctx.findAiProviderItem : function () { return null; };
    var bindResultIconImg = typeof ctx.bindResultIconImg === "function" ? ctx.bindResultIconImg : function () {};
    var iconUrlListForItem = typeof ctx.iconUrlListForItem === "function" ? ctx.iconUrlListForItem : function () { return []; };
    box.querySelectorAll("img.result-icon-img[data-provider-id]").forEach(function (img) {
      var pid = img.getAttribute("data-provider-id") || "";
      bindResultIconImg(img, iconUrlListForItem(findAiProviderItem(pid)));
    });
  }

  global.PaletteResultRow = {
    buildHtml: buildHtml,
    hydrateIcons: hydrateIcons
  };
})(typeof window !== "undefined" ? window : globalThis);
