/**
 * PalettePromptComposer — 提示词层：baseProtocol + route addon 组合
 */
(function (root) {
  function composeSystemPrompt(baseProtocol, routeResult) {
    var base = String(baseProtocol || "").trim();
    var addon =
      routeResult && routeResult.promptAddon ? String(routeResult.promptAddon).trim() : "";
    if (!addon) return base;
    if (!base) return addon;
    return base + "\n\n" + addon;
  }

  function composeSubmitPayload(routeResult, card, options) {
    options = options || {};
    card = card || {};
    routeResult = routeResult || {};
    var preserve = !!options.preserveRoute;
    var profile = preserve && card.routeProfile ? card.routeProfile : routeResult;
    var addon = profile.promptAddon != null ? String(profile.promptAddon) : "";
    if (!addon && card.promptAddon) addon = String(card.promptAddon);
    var meta = {
      routeId: profile.routeId || routeResult.routeId || card.routeId || "",
      label: profile.label || routeResult.label || "",
      preserveRoute: preserve,
      addonLen: addon.length,
      reason: preserve ? "preserve_card_route" : routeResult.reason || "fresh_route"
    };
    if (profile.uiCandidates && profile.uiCandidates.slots) meta.slots = profile.uiCandidates.slots;
    return { promptAddon: addon, promptMeta: meta, routeProfile: profile };
  }

  root.PalettePromptComposer = {
    composeSystemPrompt: composeSystemPrompt,
    composeSubmitPayload: composeSubmitPayload
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
