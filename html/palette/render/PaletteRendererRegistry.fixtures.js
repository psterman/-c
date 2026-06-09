(function (root) {
  function assert(condition, message) {
    if (!condition) throw new Error(message);
  }

  function runAllRendererRegistryFixtures() {
    var reg = root.PaletteRendererRegistry;
    var results = [];

    function run(name, fn) {
      try {
        fn();
        results.push({ fixture: name, ok: true });
      } catch (error) {
        results.push({
          fixture: name,
          ok: false,
          error: String(error && error.message ? error.message : error)
        });
      }
    }

    run("api_available", function () {
      assert(reg && typeof reg.resolveBlock === "function", "PaletteRendererRegistry missing");
    });

    run("r2_nmer_components_registered", function () {
      var names = reg.R2_NMER_COMPONENTS || [];
      assert(names.length >= 4, "r2 component list too small");
      names.forEach(function (name) {
        var entry = reg.get(name);
        assert(entry && entry.representation === reg.REPRESENTATIONS.R2, name + " not r2");
        assert(entry.backend === reg.BACKENDS.R2_NMER_LIT, name + " backend mismatch");
      });
    });

    run("r3_official_surface_and_children", function () {
      var surface = reg.get("OfficialSurface");
      assert(surface && surface.representation === reg.REPRESENTATIONS.R3, "OfficialSurface missing");
      assert(surface.backend === reg.BACKENDS.R3_OFFICIAL_SURFACE, "surface backend mismatch");
      var children = reg.listByRepresentation(reg.REPRESENTATIONS.R3);
      assert(children.length >= 7, "r3 entries too few");
      (reg.OFFICIAL_A2UI_COMPONENTS || []).forEach(function (name) {
        var entry = reg.get("r3:" + name);
        assert(entry && entry.officialComponent === name, "r3 child missing: " + name);
        assert(entry.backend === reg.BACKENDS.R3_OFFICIAL_INTERNAL, "child backend mismatch");
      });
    });

    run("resolve_r1_reply_block", function () {
      var entry = reg.resolveBlock({ type: "reply", id: "blk-1" });
      assert(entry && entry.representation === reg.REPRESENTATIONS.R1, "reply not r1");
      assert(entry.backend === reg.BACKENDS.R1_LEGACY_DOM, "reply backend mismatch");
    });

    run("resolve_r2_comparison_table", function () {
      var entry = reg.resolveBlock({
        type: "a2ui",
        component: "ComparisonTable",
        id: "blk-2"
      });
      assert(entry && entry.representation === reg.REPRESENTATIONS.R2, "ComparisonTable not r2");
      assert(entry.fallbackBackend === reg.BACKENDS.R2_NMER_LEGACY, "fallback missing");
    });

    run("describe_card_mixed_representations", function () {
      var summary = reg.describeCard({
        id: "card-mix",
        pipelineBlocks: [{ type: "reply", id: "r1" }, { type: "a2ui", component: "Steps", id: "r2" }],
        officialA2ui: { source: "go-jsonl", surfaceId: "surface-1" }
      });
      assert(summary.representations.indexOf(reg.REPRESENTATIONS.R1) >= 0, "r1 missing in describe");
      assert(summary.representations.indexOf(reg.REPRESENTATIONS.R2) >= 0, "r2 missing in describe");
      assert(summary.representations.indexOf(reg.REPRESENTATIONS.R3) >= 0, "r3 missing in describe");
      assert(summary.backends.indexOf(reg.BACKENDS.R3_OFFICIAL_SURFACE) >= 0, "surface backend missing");
    });

    run("registry_links_component_registry", function () {
      if (!root.PaletteComponentRegistry) return;
      var def = PaletteComponentRegistry.get("Steps");
      assert(!!def, "PaletteComponentRegistry Steps missing");
      var entry = reg.get("Steps");
      assert(entry && entry.registryKey === "Steps", "registry link broken");
    });

    var passed = results.filter(function (r) {
      return r.ok;
    }).length;
    var failed = results.length - passed;
    return { ok: failed === 0, passed: passed, failed: failed, results: results };
  }

  root.PaletteRendererRegistryFixtures = {
    runAllRendererRegistryFixtures: runAllRendererRegistryFixtures
  };
})(typeof window !== "undefined" ? window : globalThis);
