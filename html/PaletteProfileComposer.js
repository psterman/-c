/**
 * PaletteProfileComposer — 声明层：skill 声明 → routeProfile
 */
(function (root) {
  function buildUiCandidates(profile) {
    profile = profile || {};
    var slots = Object.assign({}, profile.uiHints || {});
    if (profile.uiCandidates && typeof profile.uiCandidates === "object") {
      return {
        a2ui: (profile.uiCandidates.a2ui || profile.a2uiCandidates || []).slice(),
        display: Object.assign({ hideOriginalTable: false }, profile.uiCandidates.display || {}),
        slots: Object.assign(slots, profile.uiCandidates.slots || {})
      };
    }
    return {
      a2ui: (profile.a2uiCandidates || []).slice(),
      display: { hideOriginalTable: profile.hideOriginalTable === true },
      slots: slots
    };
  }

  function compose(skillId, options) {
    options = options || {};
    var skill =
      root.PaletteSkillRegistry && PaletteSkillRegistry.getSkill
        ? PaletteSkillRegistry.getSkill(skillId)
        : null;
    if (!skill) skill = PaletteSkillRegistry.getSkill("general");
    var profile = skill.profile || {};
    var uiCandidates = buildUiCandidates(profile);
    var followUpChips = Array.isArray(profile.followUpChips) ? profile.followUpChips.slice() : [];
    return {
      routeId: skill.id,
      label: skill.label,
      profile: skill.id,
      promptAddon: profile.promptAddon || "",
      a2uiCandidates: uiCandidates.a2ui.slice(),
      uiCandidates: uiCandidates,
      uiHints: Object.assign({}, uiCandidates.slots || profile.uiHints || {}),
      followUpChips: followUpChips,
      confidence: options.confidence != null ? options.confidence : 1,
      reason: options.reason || "compose"
    };
  }

  function matchAndCompose(query, options) {
    options = options || {};
    if (!root.PaletteSkillRegistry || !PaletteSkillRegistry.matchSkill) {
      return compose("general", { confidence: 0.35, reason: "registry_missing" });
    }
    var matched = PaletteSkillRegistry.matchSkill(query, options);
    return compose(matched.skill.id, {
      confidence: matched.confidence,
      reason: matched.reason
    });
  }

  root.PaletteProfileComposer = {
    buildUiCandidates: buildUiCandidates,
    compose: compose,
    matchAndCompose: matchAndCompose
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
