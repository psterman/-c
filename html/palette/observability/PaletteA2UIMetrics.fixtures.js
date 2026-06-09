(function (root) {
  function assert(condition, message) {
    if (!condition) throw new Error(message);
  }

  function runAllA2UIMetricsFixtures() {
    var metrics = root.PaletteA2UIMetrics;
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
      assert(metrics && typeof metrics.recordError === "function", "metrics missing");
    });

    run("error_by_code", function () {
      metrics._resetForTest();
      metrics.recordError({ code: "A2UI_SCHEMA_INVALID", layer: "transport", source: "test" });
      metrics.recordError({ code: "A2UI_SCHEMA_INVALID", source: "test" });
      var snap = metrics.snapshot();
      assert(snap.errors === 2, "error total mismatch");
      assert(snap.errorByCode.A2UI_SCHEMA_INVALID === 2, "error code count mismatch");
    });

    run("fallback_by_hint", function () {
      metrics._resetForTest();
      metrics.recordFallback({ hint: "legacy_reply", cardId: "c1", source: "bridge" });
      var snap = metrics.snapshot();
      assert(snap.fallbacks === 1, "fallback total mismatch");
      assert(snap.fallbackByHint.legacy_reply === 1, "fallback hint mismatch");
    });

    run("action_result_status", function () {
      metrics._resetForTest();
      metrics.recordActionResult({ status: "completed", requestId: "r1" });
      metrics.recordActionResult({ status: "rejected", error: "timeout" });
      var snap = metrics.snapshot();
      assert(snap.actions === 2, "action total mismatch");
      assert(snap.actionByStatus.completed === 1, "completed count mismatch");
      assert(snap.actionByStatus.rejected === 1, "rejected count mismatch");
    });

    run("gray_route_counters", function () {
      metrics._resetForTest();
      metrics.recordGrayRoute({ route: "r3", reason: "whitelist_hit", command: "/search", allowed: true });
      metrics.recordGrayRoute({ route: "r1r2", reason: "not_whitelisted", command: "/foo" });
      var snap = metrics.snapshot();
      assert(snap.grayByRoute.r3 === 1, "r3 gray count mismatch");
      assert(snap.grayByReason.whitelist_hit === 1, "whitelist_hit reason mismatch");
    });

    run("ws_rejected_shape", function () {
      metrics._resetForTest();
      metrics.recordError({
        source: "ws_rejected",
        error: {
          schemaVersion: "nmer.a2ui.error.v1",
          code: "TPA_ENVELOPE_INVALID",
          message: "bad envelope",
          layer: "transport",
          retryable: false,
          context: { cardId: "card-1", surfaceId: "s1", seq: 2 }
        }
      });
      var snap = metrics.snapshot();
      assert(snap.errorByCode.TPA_ENVELOPE_INVALID === 1, "rejected code not recorded");
      assert(snap.recent.length === 1, "recent missing");
      assert(snap.recent[0].cardId === "card-1", "context cardId missing");
    });

    run("format_summary_lines", function () {
      metrics._resetForTest();
      metrics.recordError({ code: "RENDER_SURFACE_FALLBACK", source: "test" });
      var lines = metrics.formatSummaryLines();
      assert(lines.join("\n").indexOf("a2ui_error_total{RENDER_SURFACE_FALLBACK}=1") >= 0, "summary line missing");
    });

    var passed = results.filter(function (r) {
      return r.ok;
    }).length;
    return { ok: passed === results.length, passed: passed, failed: results.length - passed, results: results };
  }

  root.PaletteA2UIMetricsFixtures = {
    runAllA2UIMetricsFixtures: runAllA2UIMetricsFixtures
  };
})(typeof window !== "undefined" ? window : globalThis);
