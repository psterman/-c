/**
 * PaletteOfficialA2UIActionLabels fixtures
 */
(function (root) {
  function assert(cond, msg) {
    if (!cond) throw new Error(msg || "assert failed");
  }

  function runActionLabelContracts() {
    var Labels = root.PaletteOfficialA2UIActionLabels;
    assert(Labels && Labels.formatActionResult, "labels module missing");

    var cases = [
      ["accepted", true, "已受理"],
      ["completed", true, "已完成"],
      ["rejected", false, "已拒绝"],
      ["timeout", false, "已超时"],
      ["cancelled", false, "已取消"]
    ];
    for (var i = 0; i < cases.length; i++) {
      var row = cases[i];
      var out = Labels.formatActionResult({ status: row[0], requestId: "r" + i });
      assert(out.ok === row[1], row[0] + " ok mismatch");
      assert(out.title.indexOf(row[2]) >= 0, row[0] + " title mismatch");
    }

    var rejected = Labels.formatActionResult({
      status: "rejected",
      errorCode: "ACTION_NOT_ALLOWED",
      error: "action not allowed"
    });
    assert(rejected.body.indexOf("ACTION_NOT_ALLOWED") >= 0, "rejected code in body");

    var rej = Labels.formatRejected({
      error: {
        schemaVersion: "nmer.a2ui.error.v1",
        code: "TPA_ENVELOPE_INVALID",
        message: "bad envelope",
        layer: "transport"
      }
    });
    assert(rej.body.indexOf("TPA_ENVELOPE_INVALID") >= 0, "rejected frame code");
    assert(rej.title.indexOf("拒收") >= 0, "rejected title");

    var gray = Labels.formatGrayDecision({ route: "r3", reason: "whitelist_hit" });
    assert(gray.label === "R3" && gray.detail.indexOf("命中") >= 0, "gray r3 label");

    return { ok: true, name: "action_label_contracts" };
  }

  root.PaletteOfficialA2UIActionLabelsFixtures = {
    runActionLabelContracts: runActionLabelContracts
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
