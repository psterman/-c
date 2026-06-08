/**
 * ActionChips 生产路径注入 fixtures
 */
(function (root) {
  var FIXTURES = {
    action_chips_prod_inject_reply_actions: {
      description: "reply.actions 存在时自动生成 ActionChips block",
      blocks: [
        {
          id: "blk_reply_1",
          type: "reply",
          state: "final",
          seq: 2,
          turnId: 1,
          markdown: "回答正文",
          actions: [
            { id: "chip_a", label: "补充说明", kind: "safe", intent: "append", prefill: "请补充：" }
          ]
        }
      ]
    },
    action_chips_prod_skip_existing: {
      description: "blocks 已有 ActionChips 时不重复生成",
      blocks: [
        {
          id: "blk_reply_1",
          type: "reply",
          state: "final",
          seq: 2,
          turnId: 1,
          markdown: "回答",
          actions: [{ id: "chip_a", label: "A", prefill: "a" }]
        },
        {
          id: "blk_ac_existing",
          type: "a2ui",
          component: "ActionChips",
          state: "final",
          seq: 3,
          turnId: 1,
          props: { actions: [{ id: "chip_a", label: "A", prefill: "a" }] }
        }
      ]
    },
    action_chips_prod_empty_no_block: {
      description: "空 actions 不生成 block",
      blocks: [
        {
          id: "blk_reply_1",
          type: "reply",
          state: "final",
          seq: 1,
          turnId: 1,
          markdown: "无 chips"
        }
      ]
    },
    action_chips_prod_adapter_error: {
      description: "adapter 异常时 legacy FollowUpChips 仍可用",
      blocks: [
        {
          id: "blk_reply_1",
          type: "reply",
          state: "final",
          seq: 1,
          turnId: 1,
          markdown: "回答",
          actions: [{ id: "legacy_chip", label: "Legacy", prefill: "legacy text" }]
        }
      ],
      routeProfile: {
        followUpChips: [{ id: "route_chip", label: "路由", prefill: "route text" }]
      }
    },
    action_chips_prod_lit_pipeline: {
      description: "注入后的 block 进入 Lit pipeline",
      blocks: [
        {
          id: "blk_reply_1",
          type: "reply",
          state: "final",
          seq: 2,
          turnId: 1,
          markdown: "回答",
          actions: [{ id: "lit_chip", label: "Lit", prefill: "lit text" }]
        }
      ],
      useLit: true
    },
    action_chips_prod_followup_chips_only: {
      description: "仅 route followUpChips 也可注入",
      blocks: [
        {
          id: "blk_reply_1",
          type: "reply",
          state: "final",
          seq: 1,
          turnId: 1,
          markdown: "回答"
        }
      ],
      routeProfile: {
        followUpChips: [
          { id: "route_only", label: "仅路由", kind: "safe", intent: "append", prefill: "route only" }
        ]
      }
    }
  };

  function hasLog(logs, event, predicate) {
    for (var i = 0; i < logs.length; i++) {
      if (logs[i].ev !== event) continue;
      if (!predicate) return true;
      try {
        var det = logs[i].det;
        var obj = typeof det === "string" ? JSON.parse(det) : det;
        if (predicate(obj)) return true;
      } catch (_) {}
    }
    return false;
  }

  function runProdFixture(name) {
    var fx = FIXTURES[name];
    if (!fx) return { ok: false, error: "unknown_prod_fixture:" + name, fixture: name };
    if (!root.PaletteActionChipsProdInjector || !PaletteActionChipsProdInjector.injectActionChipsIntoPipelineBlocks) {
      return { ok: false, error: "prod_injector_missing", fixture: name };
    }

    var logs = [];
    var ctx = {
      cardId: "card-prod-fixture",
      debugLog: function (ev, det) {
        logs.push({ ev: ev, det: det });
      },
      followUpChips: (fx.routeProfile && fx.routeProfile.followUpChips) || []
    };

    var savedNormalize = null;
    if (name === "action_chips_prod_adapter_error" && root.PaletteActionChipsAdapter) {
      savedNormalize = PaletteActionChipsAdapter.normalizeFollowUpActionsToActionChips;
      PaletteActionChipsAdapter.normalizeFollowUpActionsToActionChips = function () {
        throw new Error("prod_adapter_throw_fixture");
      };
    }

    var injectOut;
    try {
      injectOut = PaletteActionChipsProdInjector.injectActionChipsIntoPipelineBlocks(fx.blocks, ctx);
    } finally {
      if (savedNormalize && root.PaletteActionChipsAdapter) {
        PaletteActionChipsAdapter.normalizeFollowUpActionsToActionChips = savedNormalize;
      }
    }

    var out = {
      fixture: name,
      description: fx.description || "",
      logs: logs,
      injectOut: injectOut,
      ok: true
    };

    if (name === "action_chips_prod_inject_reply_actions") {
      out.ok =
        injectOut.injected === true &&
        injectOut.blocks.length === 2 &&
        injectOut.blocks[1].component === "ActionChips" &&
        hasLog(logs, "action_chips_prod_injected") &&
        hasLog(logs, "action_chips_block_created");
      return out;
    }

    if (name === "action_chips_prod_skip_existing") {
      out.ok =
        injectOut.skipped === true &&
        injectOut.blocks.length === 2 &&
        hasLog(logs, "action_chips_prod_skip_existing") &&
        !hasLog(logs, "action_chips_prod_injected");
      return out;
    }

    if (name === "action_chips_prod_empty_no_block") {
      out.ok =
        injectOut.injected === false &&
        injectOut.blocks.length === 1 &&
        !hasLog(logs, "action_chips_prod_injected");
      return out;
    }

    if (name === "action_chips_prod_adapter_error") {
      var card = {
        id: "card-prod-fixture",
        expanded: true,
        uiState: "Done",
        routeProfile: fx.routeProfile,
        pipelineBlocks: injectOut.blocks
      };
      var legacy =
        root.PaletteActionBinder &&
        PaletteActionBinder.resolveFollowUpChips &&
        PaletteActionBinder.resolveFollowUpChips(card, { debugLog: ctx.debugLog });
      out.legacy = legacy;
      out.ok =
        injectOut.error === true &&
        injectOut.blocks.length === 1 &&
        hasLog(logs, "action_chips_prod_adapter_error") &&
        legacy &&
        legacy.length >= 2;
      return out;
    }

    if (name === "action_chips_prod_lit_pipeline") {
      if (!root.PaletteActionChipsTestHelpers) {
        return { ok: false, error: "test_helpers_missing", fixture: name };
      }
      var litRestore = null;
      if (fx.useLit) {
        litRestore = PaletteActionChipsTestHelpers.__testOnly.installLitStub();
      }
      try {
        var injected = PaletteActionChipsProdInjector.injectActionChipsIntoPipelineBlocks(fx.blocks, ctx);
        var pipe = PaletteActionChipsTestHelpers.__testOnly.runPipeline("card-prod-lit", injected.blocks, {
          card: { expanded: true, uiState: "Done" }
        });
        out.pipe = pipe;
        out.ok =
          injected.injected === true &&
          pipe.ok &&
          pipe.snap &&
          pipe.snap.ActionChips &&
          pipe.snap.ActionChips.renderer === "lit" &&
          pipe.card &&
          pipe.card._actionChipsLitRendered === true;
      } finally {
        if (litRestore) litRestore.restore();
      }
      return out;
    }

    if (name === "action_chips_prod_followup_chips_only") {
      out.ok =
        injectOut.injected === true &&
        injectOut.blocks[1] &&
        injectOut.blocks[1].props.actions[0].id === "route_only" &&
        hasLog(logs, "action_chips_prod_injected");
      return out;
    }

    return out;
  }

  function runAllProdFixtures() {
    var names = Object.keys(FIXTURES);
    var results = [];
    var passed = 0;
    var failed = 0;
    for (var i = 0; i < names.length; i++) {
      var r = runProdFixture(names[i]);
      results.push(r);
      if (r.ok) passed++;
      else failed++;
    }
    return { ok: failed === 0, passed: passed, failed: failed, results: results };
  }

  root.PaletteActionChipsProdFixtures = {
    FIXTURES: FIXTURES,
    runProdFixture: runProdFixture,
    runAllProdFixtures: runAllProdFixtures
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
