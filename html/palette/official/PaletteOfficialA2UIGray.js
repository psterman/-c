/**
 * PaletteOfficialA2UIGray — D1 灰度：officialA2ui.enabled + commandWhitelist → R3 / R1+R2
 */
(function (root) {
  function getConfig(cfg) {
    return cfg && typeof cfg === "object" ? cfg : root.nmerPaletteBridgeConfig || {};
  }

  function isForceNmerOnly(cfg) {
    cfg = getConfig(cfg);
    var rb = cfg.rollback || {};
    return rb.forceNmerOnly === true || rb.forceNmerOnly === 1 || String(rb.forceNmerOnly) === "1";
  }

  function isOfficialGloballyEnabled(cfg) {
    cfg = getConfig(cfg);
    if (isForceNmerOnly(cfg)) return false;
    var oa = cfg.officialA2ui || {};
    return oa.enabled === true || oa.enabled === 1 || String(oa.enabled) === "1";
  }

  function isBridgeReady(cfg) {
    cfg = getConfig(cfg);
    var wb = cfg.wailsBridge || {};
    if (wb.enabled === false) return false;
    return wb.healthy !== false;
  }

  function normalizeWhitelist(list) {
    if (!Array.isArray(list)) return [];
    var out = [];
    for (var i = 0; i < list.length; i++) {
      var item = String(list[i] || "").trim().toLowerCase();
      if (!item) continue;
      if (item.charAt(0) !== "/") item = "/" + item;
      if (out.indexOf(item) < 0) out.push(item);
    }
    return out;
  }

  function extractSlashCommand(query) {
    var q = String(query || "").trim();
    var m = q.match(/^(\/[a-zA-Z][\w-]*)\b/);
    return m ? String(m[1]).toLowerCase() : "";
  }

  function isQueryWhitelisted(query, whitelist) {
    var cmd = extractSlashCommand(query);
    if (!cmd) return false;
    return normalizeWhitelist(whitelist).indexOf(cmd) >= 0;
  }

  function resolveSubmit(query, cfg) {
    cfg = getConfig(cfg);
    var command = extractSlashCommand(query);
    var whitelist = normalizeWhitelist((cfg.officialA2ui || {}).commandWhitelist);
    if (isForceNmerOnly(cfg)) {
      return {
        route: "r1r2",
        allowed: false,
        reason: "force_nmer_only",
        command: command,
        whitelist: whitelist
      };
    }
    if (!isOfficialGloballyEnabled(cfg)) {
      return {
        route: "r1r2",
        allowed: false,
        reason: "official_disabled",
        command: command,
        whitelist: whitelist
      };
    }
    if (!isBridgeReady(cfg)) {
      return {
        route: "r1r2",
        allowed: false,
        reason: "bridge_not_healthy",
        command: command,
        whitelist: whitelist
      };
    }
    if (!command) {
      return {
        route: "r1r2",
        allowed: false,
        reason: "no_slash_command",
        command: "",
        whitelist: whitelist
      };
    }
    if (!whitelist.length) {
      return {
        route: "r1r2",
        allowed: false,
        reason: "whitelist_empty",
        command: command,
        whitelist: whitelist
      };
    }
    if (!isQueryWhitelisted(query, whitelist)) {
      return {
        route: "r1r2",
        allowed: false,
        reason: "not_whitelisted",
        command: command,
        whitelist: whitelist
      };
    }
    return {
      route: "r3",
      allowed: true,
      reason: "whitelist_hit",
      command: command,
      whitelist: whitelist
    };
  }

  function applyToCard(card, decision) {
    if (!card || !decision) return card;
    if (root.PaletteA2UIMetrics && PaletteA2UIMetrics.recordGrayRoute) {
      PaletteA2UIMetrics.recordGrayRoute(decision);
    }
    card.representationRoute = decision.route || "r1r2";
    card.officialA2uiRoute = decision;
    if (decision.route === "r3" && decision.allowed) {
      if (!card.officialA2ui || card.officialA2ui.source !== "go-jsonl") {
        card.officialA2ui = {
          source: "live",
          enabled: true,
          command: String(decision.command || ""),
          surfaceId: ""
        };
      }
      card.expanded = true;
    } else if (!card.officialA2ui || card.officialA2ui.source !== "go-jsonl") {
      card.officialA2ui = null;
    }
    return card;
  }

  root.PaletteOfficialA2UIGray = {
    extractSlashCommand: extractSlashCommand,
    normalizeWhitelist: normalizeWhitelist,
    isQueryWhitelisted: isQueryWhitelisted,
    isOfficialGloballyEnabled: isOfficialGloballyEnabled,
    isBridgeReady: isBridgeReady,
    isForceNmerOnly: isForceNmerOnly,
    resolveSubmit: resolveSubmit,
    applyToCard: applyToCard
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
