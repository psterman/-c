/**
 * Palette C.3-alpha fixtures — SkillRegistry / ProfileComposer / ActionPolicy / PromptComposer
 */
(function (root) {
  var FIXTURES = {
    profile_composer_research: {
      description: "matchAndCompose 研究对比路由 + followUpChips",
      query: "小米 vs Meta 对比分析"
    },
    action_policy_reject_danger: {
      description: "危险 chip 被 ActionPolicy 拒绝",
      chip: {
        id: "bad_restart",
        label: "重启 gateway 服务",
        kind: "safe",
        intent: "append",
        prefill: "请重启 gateway"
      }
    },
    followup_chips_safe: {
      description: "filterSafeActions 仅保留 safe，剔除 confirm",
      actions: [
        { id: "safe1", label: "补充说明", kind: "safe", intent: "append" },
        { id: "bad_confirm", label: "危险确认", kind: "confirm", intent: "execute" }
      ]
    },
    prompt_compose_preserve_route: {
      description: "preserveRoute 时 promptAddon 保持原路由",
      routeProfile: {
        routeId: "research_compare",
        label: "研究对比",
        promptAddon: "【路由：研究对比】ORIGINAL_ADDON",
        a2uiCandidates: ["ComparisonTable"]
      },
      card: { routeId: "research_compare", promptAddon: "【路由：研究对比】ORIGINAL_ADDON" }
    },
    lit_followup_chips: {
      description: "Lit FollowUpChips descriptor + handleAction prefill/reject + isAvailable headless",
      card: {
        id: "card-lit-fixture",
        expanded: true,
        uiState: "Done",
        routeProfile: {
          routeId: "research_compare",
          followUpChips: [
            {
              id: "lit_chip_1",
              label: "补充维度",
              kind: "safe",
              intent: "append",
              prefill: "请补充对比维度"
            }
          ]
        }
      },
      safeDetail: {
        cardId: "card-lit-fixture",
        chipId: "lit_chip_1",
        chip: {
          id: "lit_chip_1",
          label: "补充维度",
          kind: "safe",
          intent: "append",
          prefill: "请补充对比维度"
        },
        prefill: "请补充对比维度",
        source: "lit"
      },
      dangerDetail: {
        cardId: "card-lit-fixture",
        chipId: "bad_restart",
        chip: {
          id: "bad_restart",
          label: "重启 gateway 服务",
          kind: "safe",
          intent: "append",
          prefill: "请重启 gateway"
        },
        prefill: "请重启 gateway",
        source: "lit"
      }
    }
  };

  var FIXTURE_ASSERT = {
    profile_composer_research: { routeId: "research_compare", chipsMin: 1 },
    action_policy_reject_danger: { chipRejected: true },
    followup_chips_safe: { safeCount: 1 },
    prompt_compose_preserve_route: { preserveAddon: "【路由：研究对比】ORIGINAL_ADDON" },
    lit_followup_chips: {
      component: "follow-up-chips",
      slot: "actions",
      chipsMin: 1,
      handleOk: true,
      rejectOk: true,
      litUnavailable: true,
      contractKind: "chip_click",
      actionType: "prefill",
      fallbackReason: "no_lit_component",
      invalidActionRejected: true
    }
  };

  function runC3Fixture(name) {
    var fx = FIXTURES[name];
    if (!fx) return { ok: false, error: "unknown_c3_fixture:" + name, fixture: name };
    var out = { fixture: name, description: fx.description || "", ok: true };

    if (name === "profile_composer_research") {
      if (!root.PaletteProfileComposer || !PaletteProfileComposer.matchAndCompose) {
        return { ok: false, error: "composer_missing", fixture: name };
      }
      var composed = PaletteProfileComposer.matchAndCompose(fx.query);
      out.routeResult = composed;
      out.ok = composed.routeId === "research_compare" && (composed.followUpChips || []).length >= 1;
      return out;
    }

    if (name === "action_policy_reject_danger") {
      if (!root.PaletteActionPolicy || !PaletteActionPolicy.evaluateChip) {
        return { ok: false, error: "policy_missing", fixture: name };
      }
      var ev = PaletteActionPolicy.evaluateChip(fx.chip);
      out.eval = ev;
      out.ok = !ev.allowed && ev.reason;
      return out;
    }

    if (name === "followup_chips_safe") {
      if (!root.PaletteActionPolicy || !PaletteActionPolicy.filterSafeActions) {
        return { ok: false, error: "policy_missing", fixture: name };
      }
      var safe = PaletteActionPolicy.filterSafeActions(fx.actions);
      out.safe = safe;
      out.ok = safe.length === 1 && safe[0].id === "safe1";
      return out;
    }

    if (name === "prompt_compose_preserve_route") {
      if (!root.PalettePromptComposer || !PalettePromptComposer.composeSubmitPayload) {
        return { ok: false, error: "prompt_composer_missing", fixture: name };
      }
      var payload = PalettePromptComposer.composeSubmitPayload(fx.routeProfile, fx.card, {
        preserveRoute: true
      });
      out.payload = payload;
      out.ok = payload.promptAddon === fx.routeProfile.promptAddon;
      return out;
    }

    if (name === "lit_followup_chips") {
      if (!root.PaletteLitRenderer || !PaletteLitRenderer.toFollowUpChipsDescriptor) {
        return { ok: false, error: "lit_renderer_missing", fixture: name };
      }
      if (!root.PaletteActionBinder || !PaletteActionBinder.handleAction) {
        return { ok: false, error: "binder_handle_action_missing", fixture: name };
      }
      if (!root.PaletteUIEventContract || !PaletteUIEventContract.normalizePaletteAction) {
        return { ok: false, error: "event_contract_missing", fixture: name };
      }
      var chips =
        PaletteActionBinder.resolveFollowUpChips &&
        PaletteActionBinder.resolveFollowUpChips(fx.card);
      var desc = PaletteLitRenderer.toFollowUpChipsDescriptor(fx.card, chips);
      out.descriptor = desc;
      out.litAvailable = PaletteLitRenderer.isAvailable ? PaletteLitRenderer.isAvailable() : false;
      out.normalized = PaletteUIEventContract.normalizePaletteAction(fx.safeDetail);
      out.fallbackInfo =
        PaletteLitRenderer.explainLitFallback && PaletteLitRenderer.explainLitFallback({});

      var mockInput = { value: "", focusCalled: false, focus: function () { this.focusCalled = true; } };
      var mockBox = { hidden: false, innerHTML: "", querySelector: function () { return null; } };
      var mockDom = {
        querySelector: function (sel) {
          if (sel === ".card-followup-input") return mockInput;
          if (sel === ".card-followup-chips") return mockBox;
          return null;
        }
      };
      var fallbackLogs = [];
      var savedDoc = root.document;
      root.document = {
        getElementById: function (id) {
          return id === "card-" + fx.card.id ? mockDom : null;
        }
      };
      PaletteActionBinder.renderFollowUpChips(fx.card.id, fx.card, {
        debugLog: function (ev, det) {
          fallbackLogs.push({ ev: ev, det: det });
        }
      });
      out.fallbackLogs = fallbackLogs;
      var safeResult = PaletteActionBinder.handleAction(
        fx.card.id,
        fx.card,
        fx.safeDetail,
        {}
      );
      var dangerResult = PaletteActionBinder.handleAction(
        fx.card.id,
        fx.card,
        fx.dangerDetail,
        {}
      );
      if (savedDoc !== undefined) root.document = savedDoc;
      else delete root.document;

      var fbEntry = null;
      for (var fi = 0; fi < fallbackLogs.length; fi++) {
        if (fallbackLogs[fi].ev === "followup_chips_fallback") {
          fbEntry = fallbackLogs[fi];
          break;
        }
      }
      out.fallbackEntry = fbEntry;
      out.safeResult = safeResult;
      out.dangerResult = dangerResult;
      out.mockInputValue = mockInput.value;
      out.v1Normalized = PaletteUIEventContract.normalizePaletteAction({
        cardId: fx.card.id,
        chipId: "lit_chip_1",
        prefill: "请补充对比维度",
        source: "lit"
      });
      out.invalidResult = PaletteActionBinder.handleAction(
        fx.card.id,
        fx.card,
        {
          cardId: fx.card.id,
          chipId: "empty_val",
          chip: { id: "empty_val", label: "x" },
          action: { type: "prefill", value: "" },
          renderer: "lit"
        },
        {}
      );
      out.ok =
        desc &&
        desc.component === "follow-up-chips" &&
        desc.slot === "actions" &&
        desc.props &&
        desc.props.chips &&
        desc.props.chips.length >= 1 &&
        desc.props.chips[0].action &&
        desc.props.chips[0].action.type === "prefill" &&
        desc.props.visible === true &&
        out.litAvailable === false &&
        out.normalized &&
        out.normalized.kind === "chip_click" &&
        out.normalized.component === "follow-up-chips" &&
        out.normalized.slot === "actions" &&
        out.normalized.action &&
        out.normalized.action.type === "prefill" &&
        out.normalized.renderer === "lit" &&
        out.normalized.source === undefined &&
        out.normalized.prefill === undefined &&
        out.v1Normalized &&
        out.v1Normalized.action &&
        out.v1Normalized.action.value === "请补充对比维度" &&
        out.v1Normalized.renderer === "lit" &&
        out.v1Normalized.source === undefined &&
        out.v1Normalized.prefill === undefined &&
        out.fallbackInfo &&
        (out.fallbackInfo.reason === "no_lit_component" || out.fallbackInfo.reason === "lit_unavailable") &&
        fbEntry &&
        fbEntry.det &&
        (fbEntry.det.indexOf("no_lit_component") >= 0 || fbEntry.det.indexOf("lit_unavailable") >= 0) &&
        safeResult &&
        safeResult.ok === true &&
        safeResult.actionType === "prefill" &&
        safeResult.renderer === "lit" &&
        mockInput.value === "请补充对比维度" &&
        dangerResult &&
        dangerResult.ok === false &&
        dangerResult.reason &&
        out.invalidResult &&
        out.invalidResult.ok === false;
      return out;
    }

    return { ok: false, error: "empty_c3_fixture", fixture: name };
  }

  function assertC3FixtureResult(out, name) {
    var spec = FIXTURE_ASSERT[name] || {};
    var errors = [];
    if (!out || !out.ok) errors.push("ok=false" + (out && out.error ? ":" + out.error : ""));
    if (spec.routeId && (!out.routeResult || out.routeResult.routeId !== spec.routeId))
      errors.push("routeId!=" + spec.routeId);
    if (spec.chipsMin != null) {
      if (out.routeResult) {
        var n = out.routeResult.followUpChips ? out.routeResult.followUpChips.length : 0;
        if (n < spec.chipsMin) errors.push("chips<" + spec.chipsMin);
      } else if (out.descriptor) {
        var cc =
          out.descriptor.props && out.descriptor.props.chips ? out.descriptor.props.chips.length : 0;
        if (cc < spec.chipsMin) errors.push("chips<" + spec.chipsMin);
      }
    }
    if (spec.chipRejected && (!out.eval || out.eval.allowed)) errors.push("chip_not_rejected");
    if (spec.safeCount != null) {
      var sc = out.safe ? out.safe.length : 0;
      if (sc !== spec.safeCount) errors.push("safeCount!=" + spec.safeCount);
    }
    if (spec.preserveAddon) {
      if (!out.payload || out.payload.promptAddon !== spec.preserveAddon) errors.push("addon_changed");
    }
    if (spec.component) {
      if (!out.descriptor || out.descriptor.component !== spec.component) errors.push("component!=" + spec.component);
    }
    if (spec.actionsMin != null) {
      var ac =
        out.descriptor && out.descriptor.props && out.descriptor.props.actions
          ? out.descriptor.props.actions.length
          : 0;
      if (ac < spec.actionsMin) errors.push("actions<" + spec.actionsMin);
    }
    if (spec.slot) {
      if (!out.descriptor || out.descriptor.slot !== spec.slot) errors.push("slot!=" + spec.slot);
    }
    if (spec.actionType) {
      var at =
        out.descriptor &&
        out.descriptor.props &&
        out.descriptor.props.chips &&
        out.descriptor.props.chips[0] &&
        out.descriptor.props.chips[0].action
          ? out.descriptor.props.chips[0].action.type
          : "";
      if (at !== spec.actionType) errors.push("actionType!=" + spec.actionType);
    }
    if (spec.invalidActionRejected && (!out.invalidResult || out.invalidResult.ok)) {
      errors.push("invalid_action_not_rejected");
    }
    if (spec.handleOk && (!out.safeResult || !out.safeResult.ok)) errors.push("handle_not_ok");
    if (spec.rejectOk && (!out.dangerResult || out.dangerResult.ok)) errors.push("danger_not_rejected");
    if (spec.litUnavailable && out.litAvailable !== false) errors.push("lit_should_be_unavailable");
    if (spec.contractKind) {
      if (!out.normalized || out.normalized.kind !== spec.contractKind) errors.push("contract_kind");
    }
    if (spec.fallbackReason) {
      if (!out.fallbackInfo || out.fallbackInfo.reason !== spec.fallbackReason) errors.push("fallback_reason");
      if (!out.fallbackEntry) errors.push("fallback_log_missing");
    }
    return { pass: errors.length === 0, errors: errors };
  }

  function runAllC3Fixtures() {
    var names = Object.keys(FIXTURES);
    var results = [];
    var passed = 0;
    var failed = 0;
    for (var i = 0; i < names.length; i++) {
      var nm = names[i];
      var out = runC3Fixture(nm);
      var assert = assertC3FixtureResult(out, nm);
      out.assert = assert;
      if (!assert.pass) out.ok = false;
      results.push(out);
      if (out.ok && assert.pass) passed++;
      else failed++;
    }
    return { ok: failed === 0, passed: passed, failed: failed, results: results };
  }

  root.PaletteC3Fixtures = {
    FIXTURES: FIXTURES,
    runC3Fixture: runC3Fixture,
    runAllC3Fixtures: runAllC3Fixtures
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
