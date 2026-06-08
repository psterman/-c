/**

 * PaletteRouterSkill — 任务路由（委托 SkillRegistry + ProfileComposer + PromptComposer）

 */

(function (root) {

  function getProfiles() {

    if (root.PaletteSkillRegistry && PaletteSkillRegistry.toLegacyProfiles)

      return PaletteSkillRegistry.toLegacyProfiles();

    return {};

  }



  function buildUiCandidates(profile) {

    if (root.PaletteProfileComposer && PaletteProfileComposer.buildUiCandidates)

      return PaletteProfileComposer.buildUiCandidates(profile);

    return { a2ui: [], display: { hideOriginalTable: false }, slots: {} };

  }



  function route(query, options) {

    if (root.PaletteProfileComposer && PaletteProfileComposer.matchAndCompose)

      return PaletteProfileComposer.matchAndCompose(query, options || {});

    return {

      routeId: "general",

      label: "通用",

      promptAddon: "",

      a2uiCandidates: [],

      uiCandidates: { a2ui: [], display: { hideOriginalTable: false }, slots: {} },

      followUpChips: [],

      confidence: 0.35,

      reason: "composer_missing"

    };

  }



  function buildSystemPrompt(baseProtocol, routeResult) {

    if (root.PalettePromptComposer && PalettePromptComposer.composeSystemPrompt)

      return PalettePromptComposer.composeSystemPrompt(baseProtocol, routeResult);

    var base = String(baseProtocol || "").trim();

    var addon = routeResult && routeResult.promptAddon ? String(routeResult.promptAddon).trim() : "";

    if (!addon) return base;

    if (!base) return addon;

    return base + "\n\n" + addon;

  }



  root.PaletteRouterSkill = {

    get PROFILES() {

      return getProfiles();

    },

    buildUiCandidates: buildUiCandidates,

    route: route,

    buildSystemPrompt: buildSystemPrompt

  };

})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);

