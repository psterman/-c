/**
 * ActionChips vs legacy FollowUpChips 去重 fixtures
 */
(function (root) {
  var FIXTURES = {
    dedupe_skip_when_valid_lit: {
      description: "valid ActionChips block + Lit 时 legacy 不重复渲染"
    },
    dedupe_render_without_block: {
      description: "无 ActionChips block 时 legacy chips 仍渲染"
    },
    dedupe_invalid_block_fallback: {
      description: "invalid ActionChips block 时 legacy 仍可 fallback"
    },
    dedupe_lit_error_single_legacy: {
      description: "Lit render error 时只渲染一份 legacy chips"
    },
    dedupe_dom_chip_count: {
      description: "dedupe 后 DOM chip 数量正确"
    },
    dedupe_trace_reasons: {
      description: "trace reason 与策略一致"
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

  function countDomChips(mock) {
    if (!mock || !mock.chipsBox) return 0;
    var box = mock.chipsBox;
    if (box.innerHTML) {
      var legacy = box.innerHTML.match(/card-followup-chip/g);
      if (legacy && legacy.length) return legacy.length;
    }
    var lit =
      box.children &&
      box.children.filter(function (c) {
        return c && (c.tagName === "PALETTE-ACTION-CHIPS" || c.tagName === "palette-action-chips");
      });
    if (lit && lit.length) {
      var el = lit[0];
      return el.actions && el.actions.length ? el.actions.length : 0;
    }
    return box.children ? box.children.length : 0;
  }

  function runDedupeFlow(blocks, opts) {
    opts = opts || {};
    if (!root.PaletteActionChipsTestHelpers) return { ok: false, error: "test_helpers_missing" };
    var logs = [];
    var debugLog = function (ev, det) {
      logs.push({ ev: ev, det: det });
    };
    var cardId = "card-dedupe-fixture";
    var card = Object.assign(
      {
        id: cardId,
        expanded: true,
        uiState: "Done",
        pipelineBlocks: blocks,
        blockStore: { blocks: blocks }
      },
      opts.card || {}
    );

    var litRestore = null;
    if (opts.litStub) litRestore = PaletteActionChipsTestHelpers.__testOnly.installLitStub(opts.litStub);
    if (opts.noLit) litRestore = PaletteActionChipsTestHelpers.__testOnly.installLitStub({ hideLit: true });

    try {
      if (root.PaletteActionChipsProdInjector && !opts.skipInject) {
        var injected = PaletteActionChipsProdInjector.injectActionChipsIntoPipelineBlocks(blocks, {
          cardId: cardId,
          debugLog: debugLog,
          followUpChips: (card.routeProfile && card.routeProfile.followUpChips) || []
        });
        blocks = injected.blocks || blocks;
        card.pipelineBlocks = blocks;
        card.blockStore = { blocks: blocks };
      }

      var pipe = PaletteActionChipsTestHelpers.__testOnly.runPipeline(cardId, blocks, { card: card });
      var renderActionsOut = null;
      if (root.PaletteCardRenderer && PaletteCardRenderer.renderActions) {
        renderActionsOut = PaletteCardRenderer.renderActions(cardId, pipe.card, pipe.mock.dom, {
          debugLog: debugLog
        });
      }
      return {
        ok: pipe.ok,
        logs: logs,
        card: pipe.card,
        mock: pipe.mock,
        renderActionsOut: renderActionsOut,
        chipCount: countDomChips(pipe.mock)
      };
    } finally {
      if (litRestore) litRestore.restore();
    }
  }

  function runDedupeFixture(name) {
    var fx = FIXTURES[name];
    if (!fx) return { ok: false, error: "unknown_dedupe_fixture:" + name, fixture: name };

    if (name === "dedupe_skip_when_valid_lit") {
      var blocksLit = [
        {
          id: "blk_reply",
          type: "reply",
          state: "final",
          seq: 1,
          turnId: 1,
          markdown: "回答",
          actions: [{ id: "c1", label: "补充", prefill: "补充文本" }]
        }
      ];
      var flowLit = runDedupeFlow(blocksLit, { litStub: {} });
      return {
        fixture: name,
        ok:
          flowLit.ok &&
          flowLit.renderActionsOut &&
          flowLit.renderActionsOut.skippedByActionChips === true &&
          flowLit.chipCount === 1 &&
          hasLog(flowLit.logs, "legacy_actions_skipped_by_action_chips")
      };
    }

    if (name === "dedupe_render_without_block") {
      var blocksNoAc = [
        {
          id: "blk_reply",
          type: "reply",
          state: "final",
          seq: 1,
          turnId: 1,
          markdown: "回答",
          actions: [{ id: "only_legacy", label: "仅 Legacy", prefill: "legacy only" }]
        }
      ];
      var flowNo = runDedupeFlow(blocksNoAc, { skipInject: true, noLit: true });
      return {
        fixture: name,
        ok:
          flowNo.ok &&
          flowNo.renderActionsOut &&
          flowNo.renderActionsOut.renderer === "legacy" &&
          flowNo.chipCount === 1 &&
          hasLog(flowNo.logs, "legacy_actions_rendered_no_action_chips")
      };
    }

    if (name === "dedupe_invalid_block_fallback") {
      var blocksInvalid = [
        {
          id: "blk_reply",
          type: "reply",
          state: "final",
          seq: 1,
          turnId: 1,
          markdown: "回答",
          actions: [{ id: "fb_chip", label: "Fallback", prefill: "fb text" }]
        },
        {
          id: "blk_ac_bad",
          type: "a2ui",
          component: "ActionChips",
          state: "final",
          seq: 2,
          turnId: 1,
          props: { actions: [] }
        }
      ];
      var flowInv = runDedupeFlow(blocksInvalid, { skipInject: true, noLit: true });
      return {
        fixture: name,
        ok:
          flowInv.ok &&
          flowInv.renderActionsOut &&
          flowInv.renderActionsOut.renderer === "legacy" &&
          flowInv.chipCount === 1 &&
          hasLog(flowInv.logs, "legacy_actions_rendered_no_action_chips")
      };
    }

    if (name === "dedupe_lit_error_single_legacy") {
      var blocksErr = [
        {
          id: "blk_reply",
          type: "reply",
          state: "final",
          seq: 1,
          turnId: 1,
          markdown: "回答",
          actions: [{ id: "err_chip", label: "错误兜底", prefill: "err text" }]
        },
        {
          id: "blk_ac_err",
          type: "a2ui",
          component: "ActionChips",
          state: "final",
          seq: 2,
          turnId: 1,
          props: {
            actions: [{ id: "err_chip", label: "错误兜底", intent: "prefill", payload: { text: "err text" } }]
          }
        }
      ];
      var flowErr = runDedupeFlow(blocksErr, {
        skipInject: true,
        litStub: { throwOnApplyProps: true },
        card: { _actionChipsPipelineHandled: true }
      });
      var legacyRenderLogs = flowErr.logs.filter(function (l) {
        return l.ev === "followup_chips_render";
      });
      return {
        fixture: name,
        ok:
          flowErr.ok &&
          flowErr.renderActionsOut &&
          flowErr.renderActionsOut.renderer === "legacy" &&
          flowErr.chipCount === 1 &&
          hasLog(flowErr.logs, "legacy_actions_rendered_as_fallback") &&
          legacyRenderLogs.length === 1
      };
    }

    if (name === "dedupe_dom_chip_count") {
      var blocksDup = [
        {
          id: "blk_reply",
          type: "reply",
          state: "final",
          seq: 1,
          turnId: 1,
          markdown: "回答",
          actions: [
            { id: "dup1", label: "A", prefill: "a" },
            { id: "dup2", label: "B", prefill: "b" }
          ]
        }
      ];
      var flowDup = runDedupeFlow(blocksDup, {
        litStub: {},
        card: {
          routeProfile: {
            followUpChips: [{ id: "dup1", label: "A", prefill: "a" }]
          }
        }
      });
      var dedupeLogs = [];
      var merged =
        root.PaletteActionBinder &&
        PaletteActionBinder.resolveFollowUpChips &&
        PaletteActionBinder.resolveFollowUpChips(flowDup.card, {
          debugLog: function (ev, det) {
            dedupeLogs.push({ ev: ev, det: det });
          }
        });
      return {
        fixture: name,
        ok:
          flowDup.ok &&
          flowDup.chipCount === 2 &&
          merged &&
          merged.length === 2 &&
          hasLog(dedupeLogs, "legacy_actions_deduped") &&
          flowDup.renderActionsOut &&
          flowDup.renderActionsOut.skippedByActionChips === true
      };
    }

    if (name === "dedupe_trace_reasons") {
      if (!root.PaletteActionBinder || !PaletteActionBinder.evaluateLegacyFollowUpRender) {
        return { ok: false, error: "binder_missing", fixture: name };
      }
      var cardValid = {
        id: "card-trace",
        _actionChipsLitRendered: true,
        pipelineBlocks: [
          {
            id: "ac1",
            type: "a2ui",
            component: "ActionChips",
            props: { actions: [{ id: "t1", label: "T", payload: { text: "t" } }] }
          }
        ]
      };
      var mockDom = PaletteActionChipsTestHelpers.__testOnly.buildCardDom();
      var litEl = root.document.createElement("palette-action-chips");
      litEl.actions = [{ id: "t1", label: "T" }];
      mockDom.chipsBox.appendChild(litEl);
      var skipDecision = PaletteActionBinder.evaluateLegacyFollowUpRender(cardValid, mockDom.dom);
      var cardNone = { id: "card-trace", pipelineBlocks: [] };
      var renderDecision = PaletteActionBinder.evaluateLegacyFollowUpRender(cardNone, mockDom.dom);
      var cardFb = {
        id: "card-trace",
        _actionChipsPipelineHandled: true,
        pipelineBlocks: [
          {
            id: "ac2",
            type: "a2ui",
            component: "ActionChips",
            props: { actions: [{ id: "t2", label: "T2", payload: { text: "t2" } }] }
          }
        ]
      };
      var mockDomFb = PaletteActionChipsTestHelpers.__testOnly.buildCardDom();
      var fbDecision = PaletteActionBinder.evaluateLegacyFollowUpRender(cardFb, mockDomFb.dom);
      return {
        fixture: name,
        ok:
          skipDecision.mode === "skip" &&
          skipDecision.trace === "legacy_actions_skipped_by_action_chips" &&
          (skipDecision.reason === "action_chips_lit_flag" ||
            skipDecision.reason === "action_chips_lit_active") &&
          renderDecision.mode === "render" &&
          renderDecision.trace === "legacy_actions_rendered_no_action_chips" &&
          fbDecision.mode === "fallback" &&
          fbDecision.trace === "legacy_actions_rendered_as_fallback"
      };
    }

    return { ok: false, error: "unhandled", fixture: name };
  }

  function runAllDedupeFixtures() {
    var names = Object.keys(FIXTURES);
    var results = [];
    var passed = 0;
    var failed = 0;
    for (var i = 0; i < names.length; i++) {
      var r = runDedupeFixture(names[i]);
      results.push(r);
      if (r.ok) passed++;
      else failed++;
    }
    return { ok: failed === 0, passed: passed, failed: failed, results: results };
  }

  root.PaletteActionChipsDedupeFixtures = {
    FIXTURES: FIXTURES,
    runDedupeFixture: runDedupeFixture,
    runAllDedupeFixtures: runAllDedupeFixtures
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
