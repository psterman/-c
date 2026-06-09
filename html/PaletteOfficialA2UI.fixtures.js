(function (root) {
  function assert(condition, message) {
    if (!condition) throw new Error(message);
  }

  function runAllOfficialA2UIFixtures() {
    var bridge = root.PaletteOfficialA2UIBridge;
    var streamClient = root.PaletteOfficialA2UIStreamClient;
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

    run("parallel_fixture_spec", function () {
      var spec = bridge.normalizeSpec({ source: "fixture", fixtureId: "happy-six-components" });
      assert(spec && spec.fixtureId === "happy-six-components", "fixture spec missing");
    });

    run("reject_non_fixture_source", function () {
      assert(
        bridge.normalizeSpec({ source: "provider", fixtureId: "happy-six-components" }) === null,
        "provider source must stay disabled in P1"
      );
    });

    run("reject_unknown_fixture", function () {
      assert(
        bridge.normalizeSpec({ source: "fixture", fixtureId: "not-real" }) === null,
        "unknown fixture accepted"
      );
    });

    run("accept_go_jsonl_stream", function () {
      var spec = bridge.normalizeSpec({ source: "go-jsonl", surfaceId: "surface-1" });
      assert(spec && spec.surfaceId === "surface-1", "go jsonl stream rejected");
    });

    run("reject_go_jsonl_without_surface", function () {
      assert(
        bridge.normalizeSpec({ source: "go-jsonl" }) === null,
        "stream without surface accepted"
      );
    });

    run("legacy_reply_detection", function () {
      var fakeDom = {
        querySelector: function (selector) {
          return selector.indexOf("card-reply-body") >= 0 ? { nodeType: 1 } : null;
        }
      };
      assert(bridge.hasLegacyReply(fakeDom) === true, "legacy reply not detected");
    });

    run("action_frame_contract", function () {
      var frame = streamClient.buildActionFrame({
        cardId: "card-1",
        source: "go-jsonl",
        envelope: {
          eventId: "evt-1",
          requestId: "req-1",
          correlationId: "corr-1",
          surfaceId: "surface-1",
          componentId: "submit",
          actionName: "safe.follow-up",
          depth: 0,
          timeoutMs: 30000,
          abortId: "abort-1",
          data: { kind: "safe", question: "继续" },
          original: { unsafe: "must-not-cross-wire" }
        }
      });
      assert(frame && frame.type === "official_a2ui_action", "action frame missing");
      assert(frame.a2uiAction.schemaVersion === "nmer.a2ui.action.v1", "action version missing");
      assert(frame.a2uiAction.cardId === "card-1", "card id missing");
      assert(!frame.a2uiAction.original, "raw action leaked across wire");
    });

    run("reject_incomplete_action_frame", function () {
      assert(streamClient.buildActionFrame({ cardId: "card-1", source: "go-jsonl", envelope: {} }) === null,
        "incomplete action accepted");
    });

    run("fixture_action_stays_local", function () {
      assert(streamClient.buildActionFrame({
        cardId: "card-1",
        source: "fixture",
        envelope: {
          eventId: "evt-1",
          requestId: "req-1",
          correlationId: "corr-1",
          surfaceId: "nmer-a2ui-spike",
          componentId: "submit",
          actionName: "safe.follow-up",
          abortId: "abort-1"
        }
      }) === null, "fixture action leaked to Go");
    });

    run("abort_frame_contract", function () {
      var frame = streamClient.buildAbortFrame("req-1", "abort-1");
      assert(frame && frame.type === "official_a2ui_abort", "abort frame missing");
      assert(frame.a2uiAbort.schemaVersion === "nmer.a2ui.action.v1", "abort version missing");
      assert(streamClient.buildAbortFrame("", "abort-1") === null, "invalid abort accepted");
    });

    var passed = results.filter(function (item) { return item.ok; }).length;
    return {
      ok: passed === results.length,
      passed: passed,
      failed: results.length - passed,
      results: results
    };
  }

  root.PaletteOfficialA2UIFixtures = {
    runAllOfficialA2UIFixtures: runAllOfficialA2UIFixtures
  };
})(typeof window !== "undefined" ? window : globalThis);
