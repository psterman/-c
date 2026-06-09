/**
 * PaletteOfficialA2UIActionPolicy fixtures
 */
(function (root) {
  function assert(cond, msg) {
    if (!cond) throw new Error(msg || "assert failed");
  }

  function baseAction() {
    return {
      schemaVersion: "nmer.a2ui.action.v1",
      eventId: "evt-1",
      requestId: "req-1",
      correlationId: "corr-1",
      cardId: "card-1",
      surfaceId: "surface-1",
      componentId: "submit",
      actionName: "safe.follow-up",
      depth: 0,
      timeoutMs: 3000,
      abortId: "abort-1",
      data: { kind: "safe", question: "hi" }
    };
  }

  function runActionPolicyContracts() {
    var Policy = root.PaletteOfficialA2UIActionPolicy;
    assert(Policy && Policy.validate, "policy module missing");

    var ok = Policy.validate(baseAction());
    assert(ok.ok && ok.code === "ACTION_OK", "safe action should pass");

    var badName = baseAction();
    badName.actionName = "dangerous.run";
    var denied = Policy.validate(badName);
    assert(!denied.ok && denied.code === "ACTION_NOT_ALLOWED", "unsafe name");

    var unsafeKind = baseAction();
    unsafeKind.data = { kind: "dangerous" };
    var kindFail = Policy.validate(unsafeKind);
    assert(!kindFail.ok && kindFail.code === "ACTION_KIND_UNSAFE", "unsafe kind");

    return { ok: true, name: "action_policy_contracts" };
  }

  root.PaletteOfficialA2UIActionPolicyFixtures = {
    runActionPolicyContracts: runActionPolicyContracts
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
