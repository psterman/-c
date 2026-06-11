/**
 * PaletteOfficialA2UIGray fixtures
 */
(function (root) {
  function assert(cond, msg) {
    if (!cond) throw new Error(msg || "assert failed");
  }

  function runGrayRouteContracts() {
    var Gray = root.PaletteOfficialA2UIGray;
    assert(Gray && Gray.resolveSubmit, "gray module missing");

    var baseCfg = {
      wailsBridge: { enabled: true, healthy: true },
      officialA2ui: {
        enabled: true,
        commandWhitelist: ["/search", "/explain", "/compare"]
      },
      rollback: { forceNmerOnly: false }
    };

    var hit = Gray.resolveSubmit("/search 天气", baseCfg);
    assert(hit.route === "r3" && hit.allowed && hit.reason === "whitelist_hit", "search should hit");

    var miss = Gray.resolveSubmit("/unknown foo", baseCfg);
    assert(miss.route === "r1r2" && miss.reason === "not_whitelisted", "unknown should miss");

    var plain = Gray.resolveSubmit("对比姜文电影", baseCfg);
    assert(plain.route === "r1r2" && plain.reason === "no_slash_command", "plain text stays r1r2");

    var disabled = Gray.resolveSubmit(
      "/search x",
      Object.assign({}, baseCfg, { officialA2ui: { enabled: false, commandWhitelist: ["/search"] } })
    );
    assert(disabled.route === "r1r2" && disabled.reason === "official_disabled", "disabled flag");

    var forced = Gray.resolveSubmit(
      "/search x",
      Object.assign({}, baseCfg, { rollback: { forceNmerOnly: true } })
    );
    assert(forced.route === "r1r2" && forced.reason === "force_nmer_only", "force nmer only");
    assert(!Gray.isOfficialGloballyEnabled(
      Object.assign({}, baseCfg, { rollback: { forceNmerOnly: true } })
    ), "force_nmer_only must disable effective official");

    var mutexCfg = Object.assign({}, baseCfg, {
      officialA2ui: { enabled: true, commandWhitelist: ["/search"] },
      rollback: { forceNmerOnly: true }
    });
    var mutex = Gray.resolveSubmit("/search mutex", mutexCfg);
    assert(mutex.route === "r1r2" && mutex.reason === "force_nmer_only", "enabled+force mutex");

    var card = { id: "card-gray-1", officialA2ui: null };
    Gray.applyToCard(card, hit);
    assert(card.representationRoute === "r3", "card route r3");
    assert(card.officialA2ui && card.officialA2ui.source === "live", "card live official slot");

    assert(Gray.cardIsOfficialA2uiRoute(card), "cardIsOfficialA2uiRoute r3");
    assert(
      Gray.shouldSkipProseFinalize(card, { source: "hub_ws" }),
      "r3 must skip hub_ws prose"
    );
    assert(
      Gray.shouldSkipProseFinalize(card, { source: "adapter_http" }),
      "r3 must skip adapter_http prose"
    );
    assert(
      !Gray.shouldSkipProseFinalize({ representationRoute: "r1r2" }, { source: "hub_ws" }),
      "r1r2 keeps prose path"
    );

    return { ok: true, name: "gray_route_contracts" };
  }

  root.PaletteOfficialA2UIGrayFixtures = {
    runGrayRouteContracts: runGrayRouteContracts
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
