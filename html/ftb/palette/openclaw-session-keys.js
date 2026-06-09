/**
 * FTB-2 — OpenClaw sessionKey 工具（与 FTB / AHK / Go 对齐）
 */
(function (root) {
  "use strict";

  function ocCanonicalSessionKey(k) {
    var s = String(k || "").trim();
    if (!s) return "";
    if (s.indexOf("agent:") === 0) return s;
    if (s === "main") return "agent:main:main";
    return "agent:main:" + s;
  }

  function cardIdSlug(cardId) {
    var slug = String(cardId || "")
      .replace(/^card[-_]?/i, "")
      .replace(/[^a-zA-Z0-9_-]+/g, "-")
      .replace(/-+/g, "-")
      .replace(/^-|-$/g, "")
      .slice(0, 40);
    return slug || "task";
  }

  function paletteSessionKeyForCard(cardId, namespace) {
    var ns = String(namespace || "niuma-cp").trim() || "niuma-cp";
    var raw = "agent:main:" + ns + "-" + cardIdSlug(cardId);
    return ocCanonicalSessionKey(raw) || raw;
  }

  function isPaletteCpSessionKey(key) {
    var k = ocCanonicalSessionKey(key);
    return /^agent:main:niuma-cp-/i.test(k);
  }

  function isPaletteAdapterSessionKey(key) {
    var k = ocCanonicalSessionKey(key);
    return /^agent:main:niuma-adp-/i.test(k);
  }

  function isNiumaNamespaceKey(key) {
    var k = ocCanonicalSessionKey(key);
    return /^agent:main:niuma-/i.test(k);
  }

  var api = {
    ocCanonicalSessionKey: ocCanonicalSessionKey,
    cardIdSlug: cardIdSlug,
    paletteSessionKeyForCard: paletteSessionKeyForCard,
    isPaletteCpSessionKey: isPaletteCpSessionKey,
    isPaletteAdapterSessionKey: isPaletteAdapterSessionKey,
    isNiumaNamespaceKey: isNiumaNamespaceKey
  };

  root.NmerOpenClawSessionKeys = api;
  if (typeof module !== "undefined" && module.exports) {
    module.exports = api;
  }
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : global);
