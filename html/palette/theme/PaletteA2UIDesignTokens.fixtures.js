(function (root) {
  function assert(condition, message) {
    if (!condition) throw new Error(message);
  }

  function runAllDesignTokenFixtures() {
    var api = root.PaletteA2UIDesignTokens;
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
      assert(api && typeof api.getTokens === "function", "PaletteA2UIDesignTokens missing");
    });

    run("required_token_keys", function () {
      var keys = api.TOKEN_KEYS || [];
      assert(keys.indexOf("--palette-a2ui-primary") >= 0, "primary token missing");
      assert(keys.indexOf("--palette-a2ui-surface-bg") >= 0, "surface-bg token missing");
      assert(keys.length >= 10, "token set too small");
    });

    run("dark_preset_primary", function () {
      var tokens = api.getTokens("dark");
      assert(tokens["--palette-a2ui-primary"] === "#ff8d2a", "dark primary mismatch");
      assert(tokens["--palette-a2ui-surface-bg"], "dark surface-bg missing");
    });

    run("light_preset_differs", function () {
      var dark = api.getTokens("dark");
      var light = api.getTokens("light");
      assert(light["--palette-a2ui-primary"] !== dark["--palette-a2ui-primary"], "light primary must differ");
      assert(light["--palette-a2ui-on-surface"] !== dark["--palette-a2ui-on-surface"], "light on-surface must differ");
    });

    run("apply_to_root_mock", function () {
      var props = {};
      var mock = {
        style: {
          setProperty: function (name, value) {
            props[name] = value;
          }
        }
      };
      assert(api.applyTokens(mock, "dark") === true, "applyTokens failed");
      assert(props["--palette-a2ui-primary"] === "#ff8d2a", "mock root primary not set");
      assert(props["--palette-a2ui-surface-bg"], "mock root surface-bg not set");
    });

    run("host_alias_sync", function () {
      var props = {};
      var mock = {
        style: {
          setProperty: function (name, value) {
            props[name] = value;
          }
        }
      };
      assert(
        api.applyTokens(mock, "light", { syncHostAliases: true }) === true,
        "host apply failed"
      );
      assert(
        props["--a2ui-primary-color"] === props["--palette-a2ui-primary"],
        "host alias not synced"
      );
    });

    var passed = results.filter(function (r) {
      return r.ok;
    }).length;
    var failed = results.length - passed;
    return { ok: failed === 0, passed: passed, failed: failed, results: results };
  }

  root.PaletteA2UIDesignTokensFixtures = {
    runAllDesignTokenFixtures: runAllDesignTokenFixtures
  };
})(typeof window !== "undefined" ? window : globalThis);
