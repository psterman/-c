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
    }
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

  function runPalettePipelineFixture(name, cardId) {
    var fx = getFixture(name);
    if (!fx) return { ok: false, error: "unknown_fixture:" + name };
    var out = { fixture: name, description: fx.description || "" };
    var renderFn = getMockRenderer();
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

  root.PaletteBlockFixtures = {
    FIXTURES: FIXTURES,
    getFixture: getFixture,
    runPalettePipelineFixture: runPalettePipelineFixture
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
