/**
 * Palette Pipeline fixtures — mock blocks 验收
 */
(function (root) {
  var FIXTURES = {
    mock_all_slots: {
      description: "各槽位 mock blocks",
      blocks: [
        {
          id: "blk_mock_plan",
          type: "plan",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 1,
          turnId: 1,
          traceId: "tr_mock",
          items: [
            { text: "检查 gateway 状态", state: "done" },
            { text: "重启 gateway", state: "interrupted" }
          ]
        },
        {
          id: "blk_mock_status",
          type: "status",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 2,
          turnId: 1,
          traceId: "tr_mock",
          items: [{ text: "gateway 重启被中断", level: "warning" }]
        },
        {
          id: "blk_mock_question",
          type: "question",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 3,
          turnId: 1,
          traceId: "tr_mock",
          title: "要继续吗？",
          markdown: "M3 升级只差最后一步——重启生效。",
          status: "waiting"
        },
        {
          id: "blk_mock_reply",
          type: "reply",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 4,
          turnId: 1,
          traceId: "tr_mock",
          title: "任务回复",
          markdown: "早上好！\n\n## 结论\n\n可以继续重启 gateway。"
        },
        {
          id: "blk_mock_a2ui",
          type: "a2ui",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 5,
          turnId: 1,
          traceId: "tr_mock",
          component: "ComparisonTable",
          props: { columns: ["A", "B"], rows: [["1", "2"]] }
        }
      ]
    },
    protocol_basic: {
      description: "四标签 protocol finalize 输入样例",
      rawAnswer:
        "::PLAN_START:: 步骤1：检查 | 步骤2：重启 ::PLAN_END::\n" +
        "::STATUS_START:: [执行器] 进行中\n日志 ::STATUS_END::\n" +
        "::REPLY_START:: 任务完结\n早上好！ ::REPLY_END::"
    },
    plain_markdown: {
      description: "无标签纯 Markdown → raw reply fallback",
      rawAnswer: "早上好！\n\n**结论**：可以继续。"
    },
    stream_plain: {
      description: "ingestDelta 流式纯 Markdown",
      deltas: ["早上", "好！", "\n\n**结论**：", "可以继续。"]
    },
    stream_status_then_reply: {
      description: "ingestDelta 状态行 + 实质回复",
      deltas: ["📨 OpenClaw 已发送: chat.send", "早上好！这是回复。"]
    },
    research_table: {
      description: "Markdown 表格 → ComparisonTable A2UI",
      rawAnswer:
        "对比结论如下：\n\n| 维度 | 小米 | Meta |\n|---|---|---|\n| 优势 | 生态 | VR |\n| 风险 | 监管 | 隐私 |",
      route: { routeId: "research_compare", a2uiCandidates: ["ComparisonTable"] }
    },
    follow_up_merge: {
      description: "Phase4 append：turn1 reply 保留 + turn2 新 segment 合并",
      turnId: 2,
      priorBlocks: [
        {
          id: "blk_turn1",
          type: "reply",
          state: "final",
          source: "raw",
          confidence: 0.8,
          seq: 1,
          turnId: 1,
          traceId: "fx_t1",
          title: "任务回复",
          markdown: "第一轮：芜湖大司马是知名主播。"
        }
      ],
      segmentRaw: "第二轮补充：经典语录包括「回首掏」。"
    },
    execute_steps: {
      description: "numbered list → Steps A2UI",
      rawAnswer:
        "执行计划如下：\n\n1. 检查 gateway 状态\n2. 重启 gateway 服务\n3. 验证端口连通",
      route: { routeId: "execute_task", a2uiCandidates: ["Steps", "Alert"] }
    },
    debug_alert: {
      description: "warning/error marker → Alert A2UI",
      rawAnswer: "诊断结果：\n\n⚠ gateway 端口被占用\n\n建议先释放 18789 再重启。",
      route: { routeId: "debug_fix", a2uiCandidates: ["Alert"] }
    },
    replay_blockstore: {
      description: "BlockStore pack/unpack + render replay",
      replayFrom: "research_table"
    },
    legacy_raw_replay: {
      description: "旧卡 rawAnswer-only → re-finalize 生成 reply block",
      rawAnswer: "早上好！\n\n**结论**：重启 gateway 后可继续。",
      legacyReplay: true
    },
    legacy_raw_replay_table: {
      description: "旧卡 rawAnswer + route → reply + ComparisonTable",
      rawAnswer:
        "对比结论如下：\n\n| 维度 | 小米 | Meta |\n|---|---|---|\n| 优势 | 生态 | VR |",
      route: { routeId: "research_compare", a2uiCandidates: ["ComparisonTable"] },
      legacyReplay: true
    },
    a2ui_render_fail: {
      description: "未知 component → render 失败，reply markdown 仍保留（DOM 手测）",
      blocks: [
        {
          id: "blk_legacy_reply",
          type: "reply",
          state: "final",
          source: "raw",
          confidence: 0.8,
          seq: 1,
          turnId: 1,
          traceId: "fx_fail",
          title: "任务回复",
          markdown: "正文应完整保留，即使 A2UI slot 被移除。"
        },
        {
          id: "blk_bad_a2ui",
          type: "a2ui",
          state: "final",
          source: "heuristic",
          confidence: 0.5,
          seq: 2,
          turnId: 1,
          traceId: "fx_fail",
          component: "UnknownWidget",
          props: {}
        }
      ]
    }
  };

  var FIXTURE_ASSERT = {
    execute_steps: { a2uiComponent: "Steps" },
    debug_alert: { a2uiComponent: "Alert" },
    research_table: { a2uiComponent: "ComparisonTable", replyNoTable: true },
    replay_blockstore: { a2uiComponent: "ComparisonTable", checkDom: true, replyNoTable: true },
    follow_up_merge: { replyCountMin: 2 },
    mock_all_slots: { a2uiComponent: "ComparisonTable" },
    legacy_raw_replay: { hasReply: true },
    legacy_raw_replay_table: { hasReply: true, a2uiComponent: "ComparisonTable", replyNoTable: true },
    a2ui_render_fail: { hasReply: true }
  };

  function getFixture(name) {
    return FIXTURES[name] || null;
  }

  function getMockRenderer() {
    if (typeof root.runMockRenderBlocks === "function") return root.runMockRenderBlocks;
    if (root.nmerPalette && typeof root.nmerPalette.runMockRenderBlocks === "function")
      return root.nmerPalette.runMockRenderBlocks;
    return null;
  }

  function hasA2uiComponent(blocks, component) {
    return (blocks || []).some(function (b) {
      return b && b.type === "a2ui" && b.component === component;
    });
  }

  function assertFixtureResult(out, name) {
    var spec = FIXTURE_ASSERT[name] || {};
    var errors = [];
    if (!out || !out.ok) errors.push("ok=false" + (out && out.error ? ":" + out.error : ""));
    if (spec.a2uiComponent && !hasA2uiComponent(out && out.blocks, spec.a2uiComponent))
      errors.push("missing_a2ui:" + spec.a2uiComponent);
    if (spec.replyCountMin != null && (out.replyCount == null || out.replyCount < spec.replyCountMin))
      errors.push("replyCount<" + spec.replyCountMin);
    if (spec.hasReply) {
      var hasReplyBlock =
        out.hasReply ||
        (out.blocks || []).some(function (b) {
          return b && b.type === "reply" && String(b.markdown || "").trim();
        });
      if (!hasReplyBlock) errors.push("missing_reply");
    }
    if (spec.replyNoTable) {
      var replyWithTable = (out.blocks || []).some(function (b) {
        return b && b.type === "reply" && /\|/.test(String(b.markdown || "")) && /---/.test(String(b.markdown || ""));
      });
      if (replyWithTable) errors.push("reply_still_has_table");
    }
    if (spec.checkDom && typeof document !== "undefined") {
      if (!document.querySelector(".card-a2ui .a2ui-slot")) errors.push("missing_dom:.card-a2ui .a2ui-slot");
    }
    return { pass: errors.length === 0, errors: errors };
  }

  function runReplayBlockstoreFixture(fx, name, cardId, renderFn) {
    var srcName = fx.replayFrom || "research_table";
    var src = getFixture(srcName);
    if (!src || src.rawAnswer == null || !root.PaletteBlockPipeline) {
      return { ok: false, error: "replay_source_missing:" + srcName, fixture: name };
    }
    var finOpts = { traceId: "fx_replay_" + name, route: src.route || {} };
    var result = PaletteBlockPipeline.finalize(src.rawAnswer, finOpts);
    if (!root.PaletteBlockStore || !PaletteBlockStore.pack || !PaletteBlockStore.unpack) {
      return { ok: false, error: "blockstore_unavailable", fixture: name };
    }
    var packed = PaletteBlockStore.pack(result.blocks);
    var store = PaletteBlockStore.unpack(packed);
    var blocks = store && store.blocks ? store.blocks : [];
    var out = {
      fixture: name,
      description: fx.description || "",
      input: { replayFrom: srcName, packedBlocks: blocks.length },
      blocks: blocks,
      meta: result.meta,
      blockStore: store,
      ok: blocks.length > 0 && hasA2uiComponent(blocks, "ComparisonTable")
    };
    if (renderFn) out.render = renderFn(cardId || "mock-fixture-replay", blocks);
    return out;
  }

  function runPalettePipelineFixture(name, cardId) {
    var fx = getFixture(name);
    if (!fx) return { ok: false, error: "unknown_fixture:" + name };
    var out = { fixture: name, description: fx.description || "" };
    var renderFn = getMockRenderer();
    if (fx.replayFrom != null) {
      out = runReplayBlockstoreFixture(fx, name, cardId, renderFn);
      var replayAssert = assertFixtureResult(out, name);
      out.assert = replayAssert;
      if (!replayAssert.pass) out.ok = false;
      return out;
    }
    if (fx.legacyReplay && fx.rawAnswer != null && root.PaletteBlockPipeline) {
      var legRoute = fx.route || {};
      var legResult = PaletteBlockPipeline.finalize(fx.rawAnswer, {
        traceId: "fx_legacy_" + name,
        route: legRoute
      });
      out.input = { legacyReplay: true, rawLen: String(fx.rawAnswer).length, hadBlockStore: false };
      out.blocks = legResult.blocks;
      out.meta = legResult.meta;
      out.hasReply = (legResult.blocks || []).some(function (b) {
        return b && b.type === "reply" && String(b.markdown || "").trim();
      });
      out.ok = !!out.hasReply;
      if (renderFn) out.render = renderFn(cardId || "mock-fixture-legacy", legResult.blocks);
      return out;
    }
    if (fx.blocks) {
      out.input = { blocks: fx.blocks.length };
      out.blocks = fx.blocks;
      if (root.PaletteBlockSchema) out.blocks = PaletteBlockSchema.validateBlocks(fx.blocks).blocks;
      if (renderFn) out.render = renderFn(cardId || "mock-fixture-card", out.blocks);
      out.ok = true;
      return out;
    }
    if (fx.rawAnswer != null && root.PaletteBlockPipeline) {
      out.input = { rawLen: String(fx.rawAnswer).length };
      var finOpts = { traceId: "fx_" + name, route: fx.route || {} };
      var result = PaletteBlockPipeline.finalize(fx.rawAnswer, finOpts);
      out.blocks = result.blocks;
      out.meta = result.meta;
      if (root.PaletteBlockStore && PaletteBlockStore.pack) out.blockStore = PaletteBlockStore.pack(result.blocks);
      if (renderFn) out.render = renderFn(cardId || "mock-fixture-card", result.blocks);
      out.ok = true;
      return out;
    }
    if (fx.priorBlocks && fx.segmentRaw != null && root.PaletteBlockPipeline && PaletteBlockPipeline.mergeSegmentBlocks) {
      var segFin = PaletteBlockPipeline.finalize(fx.segmentRaw, {
        turnId: fx.turnId != null ? fx.turnId : 2,
        traceId: "fx_seg_" + name
      });
      var mergedOut = PaletteBlockPipeline.mergeSegmentBlocks(fx.priorBlocks, segFin.blocks);
      out.input = { prior: fx.priorBlocks.length, segmentLen: String(fx.segmentRaw).length };
      out.blocks = mergedOut.blocks;
      out.meta = segFin.meta;
      out.replyCount = (mergedOut.blocks || []).filter(function (b) {
        return b && b.type === "reply";
      }).length;
      out.ok = out.replyCount >= 2;
      if (renderFn) out.render = renderFn(cardId || "mock-fixture-card", mergedOut.blocks);
      return out;
    }
    if (Array.isArray(fx.deltas) && fx.deltas.length && root.PaletteBlockPipeline) {
      var state = PaletteBlockPipeline.createIngestState({ traceId: "fx_" + name });
      var lastIngest = null;
      for (var di = 0; di < fx.deltas.length; di++) {
        lastIngest = PaletteBlockPipeline.ingestDelta(state, fx.deltas[di]);
      }
      var fin =
        state.rawBuffer && PaletteBlockPipeline.finalizeFromState
          ? PaletteBlockPipeline.finalizeFromState(state)
          : PaletteBlockPipeline.finalize(state.rawBuffer, { traceId: "fx_" + name });
      out.input = { deltas: fx.deltas.length, rawLen: String(state.rawBuffer || "").length };
      out.ingest = lastIngest;
      out.blocks = fin.blocks;
      out.meta = fin.meta;
      if (renderFn) out.render = renderFn(cardId || "mock-fixture-card", fin.blocks);
      out.ok = true;
      return out;
    }
    return { ok: false, error: "empty_fixture" };
  }

  function runAllPaletteFixtures() {
    var names = Object.keys(FIXTURES);
    var results = [];
    var passed = 0;
    var failed = 0;
    for (var i = 0; i < names.length; i++) {
      var nm = names[i];
      var out = runPalettePipelineFixture(nm, "mock-fixture-" + nm);
      var spec = FIXTURE_ASSERT[nm];
      var assert = spec ? assertFixtureResult(out, nm) : { pass: !!out.ok, errors: out.ok ? [] : ["ok=false"] };
      if (!assert.pass && out.ok) {
        out.ok = false;
        out.assertErrors = assert.errors;
      } else if (!out.ok && assert.pass && spec) {
        assert = { pass: false, errors: ["ok=false"] };
      }
      out.assert = assert;
      results.push(out);
      if (out.ok && assert.pass) passed++;
      else failed++;
    }
    return { ok: failed === 0, passed: passed, failed: failed, results: results };
  }

  root.PaletteBlockFixtures = {
    FIXTURES: FIXTURES,
    FIXTURE_ASSERT: FIXTURE_ASSERT,
    getFixture: getFixture,
    assertFixtureResult: assertFixtureResult,
    runPalettePipelineFixture: runPalettePipelineFixture,
    runAllPaletteFixtures: runAllPaletteFixtures
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
