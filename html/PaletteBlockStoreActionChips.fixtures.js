/**
 * PaletteBlockStore ActionChips pack / replay fixtures
 */
(function (root) {
  var FIXTURES = {
    action_chips_store_pack_valid: {
      description: "valid ActionChips pack 后 props.actions 保留"
    },
    action_chips_store_pack_dropped: {
      description: "empty / invalid ActionChips pack 后被丢弃"
    },
    action_chips_store_replay_schema: {
      description: "replay 后通过 schema validation"
    },
    action_chips_store_pack_truncates: {
      description: "过长 label / payload 被截断"
    },
    action_chips_store_pack_strips_unknown: {
      description: "unknown fields 不会持久化"
    },
    action_chips_store_replay_lit: {
      description: "replay 后仍能进入 Lit pipeline"
    },
    action_chips_store_invalid_no_block_other: {
      description: "无效 ActionChips 不阻塞其他 block replay"
    }
  };

  function sampleBlock(overrides) {
    return Object.assign(
      {
        id: "blk_ac_store",
        type: "a2ui",
        component: "ActionChips",
        state: "final",
        source: "system",
        confidence: 1,
        seq: 3,
        turnId: 1,
        traceId: "fx_store",
        props: {
          actions: [
            {
              id: "chip_store_1",
              label: "补充说明",
              intent: "append",
              payload: { text: "请补充更多细节" },
              tone: "neutral",
              disabled: false
            }
          ]
        }
      },
      overrides || {}
    );
  }

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

  function runStoreFixture(name) {
    var fx = FIXTURES[name];
    if (!fx) return { ok: false, error: "unknown_store_fixture:" + name, fixture: name };
    if (!root.PaletteBlockStore || !PaletteBlockStore.packBlock || !PaletteBlockStore.unpack) {
      return { ok: false, error: "blockstore_missing", fixture: name };
    }

    var logs = [];
    var opts = {
      debugLog: function (ev, det) {
        logs.push({ ev: ev, det: det });
      }
    };

    if (name === "action_chips_store_pack_valid") {
      var block = sampleBlock();
      var packed = PaletteBlockStore.packBlock(block, opts);
      return {
        fixture: name,
        ok:
          !!packed &&
          packed.component === "ActionChips" &&
          packed.props &&
          packed.props.actions &&
          packed.props.actions.length === 1 &&
          packed.props.actions[0].id === "chip_store_1" &&
          packed.props.actions[0].payload.text === "请补充更多细节" &&
          hasLog(logs, "action_chips_block_packed")
      };
    }

    if (name === "action_chips_store_pack_dropped") {
      var emptyPacked = PaletteBlockStore.packBlock(
        sampleBlock({ props: { actions: [] } }),
        opts
      );
      var invalidPacked = PaletteBlockStore.packBlock(
        sampleBlock({ props: { actions: [{ id: "bad" }] } }),
        opts
      );
      return {
        fixture: name,
        ok:
          emptyPacked === null &&
          invalidPacked === null &&
          hasLog(logs, "action_chips_block_pack_dropped")
      };
    }

    if (name === "action_chips_store_replay_schema") {
      var src = sampleBlock();
      var store = PaletteBlockStore.pack([src], { debugLog: opts.debugLog });
      var replayed = PaletteBlockStore.unpack(store, opts);
      var validated =
        root.PaletteBlockSchema && PaletteBlockSchema.validateBlocks
          ? PaletteBlockSchema.validateBlocks(replayed.blocks)
          : { blocks: replayed.blocks };
      return {
        fixture: name,
        ok:
          validated.blocks &&
          validated.blocks.length === 1 &&
          validated.blocks[0].component === "ActionChips" &&
          validated.blocks[0].props.actions[0].label === "补充说明" &&
          hasLog(logs, "action_chips_block_packed") &&
          hasLog(logs, "action_chips_block_replayed")
      };
    }

    if (name === "action_chips_store_pack_truncates") {
      var longLabel = new Array(200).join("标");
      var longText = new Array(3000).join("x");
      var truncPacked = PaletteBlockStore.packBlock(
        sampleBlock({
          props: {
            actions: [
              {
                id: "long_chip",
                label: longLabel,
                intent: "prefill",
                payload: { text: longText }
              }
            ]
          }
        }),
        opts
      );
      var labelMax =
        root.PaletteBlockSchema && PaletteBlockSchema.LIMITS
          ? PaletteBlockSchema.LIMITS.MAX_ACTION_CHIP_LABEL
          : 120;
      var textMax =
        root.PaletteBlockSchema && PaletteBlockSchema.LIMITS
          ? PaletteBlockSchema.LIMITS.MAX_ACTION_CHIP_PAYLOAD_TEXT
          : 2000;
      var act = truncPacked && truncPacked.props && truncPacked.props.actions[0];
      return {
        fixture: name,
        ok:
          !!act &&
          act.label.length <= labelMax &&
          act.payload.text.length <= textMax &&
          act.payload.text.length === textMax
      };
    }

    if (name === "action_chips_store_pack_strips_unknown") {
      var dirty = sampleBlock({
        props: {
          secret: "should_not_persist",
          actions: [
            {
              id: "chip_clean",
              label: "干净",
              intent: "submit",
              payload: { text: "ok", onClick: "evil()", domRef: { x: 1 } },
              kind: "safe",
              prefill: "legacy",
              __proto__: "hack"
            }
          ]
        }
      });
      var cleanPacked = PaletteBlockStore.packBlock(dirty, opts);
      var act2 = cleanPacked && cleanPacked.props && cleanPacked.props.actions[0];
      var payloadKeys = act2 && act2.payload ? Object.keys(act2.payload).sort().join(",") : "";
      var actionKeys = act2 ? Object.keys(act2).sort().join(",") : "";
      return {
        fixture: name,
        ok:
          !!cleanPacked &&
          !("secret" in (cleanPacked.props || {})) &&
          payloadKeys === "text" &&
          actionKeys.indexOf("kind") < 0 &&
          actionKeys.indexOf("prefill") < 0 &&
          act2.payload.text === "ok"
      };
    }

    if (name === "action_chips_store_replay_lit") {
      if (!root.PaletteActionChipsTestHelpers) {
        return { ok: false, error: "test_helpers_missing", fixture: name };
      }
      var litRestore = PaletteActionChipsTestHelpers.__testOnly.installLitStub({});
      try {
        var litStore = PaletteBlockStore.pack([sampleBlock()], { debugLog: opts.debugLog });
        var litReplay = PaletteBlockStore.unpack(litStore, opts);
        var pipe = PaletteActionChipsTestHelpers.__testOnly.runPipeline(
          "card-store-lit",
          litReplay.blocks,
          { card: { expanded: true, uiState: "Done" } }
        );
        return {
          fixture: name,
          ok:
            pipe.ok &&
            pipe.snap &&
            pipe.snap.ActionChips &&
            pipe.snap.ActionChips.renderer === "lit" &&
            hasLog(logs, "action_chips_block_replayed")
        };
      } finally {
        litRestore.restore();
      }
    }

    if (name === "action_chips_store_invalid_no_block_other") {
      var mixed = [
        {
          id: "blk_reply_keep",
          type: "reply",
          state: "final",
          seq: 1,
          turnId: 1,
          markdown: "保留回复"
        },
        sampleBlock({ id: "blk_ac_bad", props: { actions: [] } }),
        {
          id: "blk_table_keep",
          type: "a2ui",
          component: "Alert",
          state: "final",
          seq: 2,
          turnId: 1,
          props: { variant: "info", text: "提示保留" }
        }
      ];
      var mixedPacked = PaletteBlockStore.pack(mixed, { debugLog: opts.debugLog });
      var mixedReplay = PaletteBlockStore.unpack(mixedPacked, opts);
      return {
        fixture: name,
        ok:
          mixedPacked.blocks.length === 2 &&
          mixedReplay.blocks.length === 2 &&
          mixedReplay.blocks.some(function (b) {
            return b && b.type === "reply";
          }) &&
          mixedReplay.blocks.some(function (b) {
            return b && b.component === "Alert";
          }) &&
          !mixedReplay.blocks.some(function (b) {
            return b && b.component === "ActionChips";
          })
      };
    }

    return { ok: false, error: "unhandled", fixture: name };
  }

  function runAllStoreFixtures() {
    var names = Object.keys(FIXTURES);
    var results = [];
    var passed = 0;
    var failed = 0;
    for (var i = 0; i < names.length; i++) {
      var r = runStoreFixture(names[i]);
      results.push(r);
      if (r.ok) passed++;
      else failed++;
    }
    return { ok: failed === 0, passed: passed, failed: failed, results: results };
  }

  root.PaletteBlockStoreActionChipsFixtures = {
    FIXTURES: FIXTURES,
    runStoreFixture: runStoreFixture,
    runAllStoreFixtures: runAllStoreFixtures
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
